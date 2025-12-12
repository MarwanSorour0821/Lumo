"""
AWS Textract utility functions for parsing blood test documents.
Extracts text, tables, and key-value pairs from uploaded documents.
"""
import os
import time
import json
import logging
import boto3

# Configure logging
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def get_textract_client():
    """
    Create and return an AWS Textract client using environment credentials.
    """
    region = os.getenv("AWS_REGION")
    logger.info(f"Creating Textract client in region: {region}")
    return boto3.client(
        "textract",
        region_name=region,
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    )


def get_s3_client():
    """
    Create and return an AWS S3 client using environment credentials.
    """
    return boto3.client(
        "s3",
        region_name=os.getenv("AWS_REGION"),
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    )


def extract_kv_relationships(blocks):
    """
    Extract key-value pairs from Textract blocks.
    Used for form-style data like "Patient Name: John Doe"
    
    Returns:
        dict: key -> value mapping
    """
    block_map = {b['Id']: b for b in blocks}
    key_map = {}
    value_map = {}
    
    for b in blocks:
        if b['BlockType'] == 'KEY_VALUE_SET':
            if 'KEY' in b.get('EntityTypes', []):
                key_map[b['Id']] = b
            else:
                value_map[b['Id']] = b

    def get_text(block):
        """Extract text from a block by following CHILD relationships."""
        text = ''
        if 'Relationships' in block:
            for rel in block['Relationships']:
                if rel['Type'] == 'CHILD':
                    for cid in rel['Ids']:
                        ch = block_map.get(cid)
                        if ch:
                            if ch['BlockType'] == 'WORD':
                                text += ch['Text'] + ' '
                            elif ch['BlockType'] == 'SELECTION_ELEMENT':
                                if ch.get('SelectionStatus') == 'SELECTED':
                                    text += 'X '
        return text.strip()

    kvs = {}
    # Link keys to values by VALUE relationships
    for k_id, k_block in key_map.items():
        key_text = get_text(k_block)
        value_text = ''
        if 'Relationships' in k_block:
            for rel in k_block['Relationships']:
                if rel['Type'] == 'VALUE':
                    for v_id in rel['Ids']:
                        v_block = block_map.get(v_id)
                        if v_block:
                            value_text = get_text(v_block)
        if key_text:
            kvs[key_text] = value_text

    return kvs


def extract_tables(blocks):
    """
    Extract tables from Textract blocks.
    
    Returns:
        list: List of tables, where each table is a list of rows,
              and each row is a list of cell text values.
    """
    block_map = {b['Id']: b for b in blocks}
    tables = []
    
    for b in blocks:
        if b['BlockType'] == 'TABLE':
            cells = []
            
            if 'Relationships' in b:
                for rel in b['Relationships']:
                    if rel['Type'] == 'CHILD':
                        for cid in rel['Ids']:
                            c = block_map.get(cid)
                            if c and c['BlockType'] == 'CELL':
                                row_index = c.get('RowIndex', 1)
                                col_index = c.get('ColumnIndex', 1)
                                text = ""
                                
                                # Gather child words
                                if 'Relationships' in c:
                                    for r2 in c['Relationships']:
                                        if r2['Type'] == 'CHILD':
                                            for child_id in r2['Ids']:
                                                ch = block_map.get(child_id)
                                                if ch and ch['BlockType'] == 'WORD':
                                                    text += ch['Text'] + ' '
                                
                                cells.append((row_index, col_index, text.strip()))
            
            # Build 2D grid from cells
            if cells:
                max_row = max(c[0] for c in cells)
                max_col = max(c[1] for c in cells)
                table = [["" for _ in range(max_col)] for _ in range(max_row)]
                for r, c, text in cells:
                    table[r-1][c-1] = text
                tables.append(table)
    
    return tables


def blocks_to_structured(blocks):
    """
    Convert Textract blocks to a structured dictionary.
    
    Returns:
        dict: {
            "lines": list of text lines,
            "key_values": dict of key-value pairs,
            "tables": list of tables
        }
    """
    lines = []
    for b in blocks:
        if b['BlockType'] == 'LINE':
            lines.append(b.get('Text', ''))
    
    kv = extract_kv_relationships(blocks)
    tables = extract_tables(blocks)
    
    return {
        "lines": lines,
        "key_values": kv,
        "tables": tables
    }


def upload_to_s3(file_obj, filename):
    """
    Upload a file to S3 and return the S3 key.
    
    Args:
        file_obj: File-like object to upload
        filename: Original filename
        
    Returns:
        str: S3 key where file was uploaded
    """
    s3 = get_s3_client()
    bucket = os.getenv("AWS_S3_BUCKET")
    s3_key = f"textract_uploads/{int(time.time())}_{filename}"
    
    logger.info(f"📤 Uploading file to S3...")
    logger.info(f"   Bucket: {bucket}")
    logger.info(f"   Key: {s3_key}")
    
    # Reset file pointer if possible
    if hasattr(file_obj, 'seek'):
        file_obj.seek(0)
    
    s3.upload_fileobj(file_obj, bucket, s3_key)
    logger.info(f"✅ Upload complete!")
    return s3_key


def delete_from_s3(s3_key):
    """
    Delete a file from S3.
    
    Args:
        s3_key: S3 key of the file to delete
    """
    try:
        s3 = get_s3_client()
        bucket = os.getenv("AWS_S3_BUCKET")
        s3.delete_object(Bucket=bucket, Key=s3_key)
        logger.info(f"🗑️  Cleaned up S3 file: {s3_key}")
    except Exception as e:
        logger.warning(f"Failed to cleanup S3 file: {e}")


def run_textract_analysis(s3_key, max_wait_seconds=120):
    """
    Run Textract document analysis on an S3 object.
    
    Args:
        s3_key: S3 key of the document to analyze
        max_wait_seconds: Maximum time to wait for completion
        
    Returns:
        list: All Textract blocks from the analysis
        
    Raises:
        Exception: If Textract job fails or times out
    """
    textract = get_textract_client()
    bucket = os.getenv("AWS_S3_BUCKET")
    
    logger.info(f"🔍 Starting Textract document analysis...")
    logger.info(f"   Bucket: {bucket}")
    logger.info(f"   S3 Key: {s3_key}")
    logger.info(f"   Features: TABLES, FORMS")
    
    # Start async analysis with TABLES and FORMS features
    start_resp = textract.start_document_analysis(
        DocumentLocation={
            'S3Object': {
                'Bucket': bucket,
                'Name': s3_key
            }
        },
        FeatureTypes=['TABLES', 'FORMS']
    )
    job_id = start_resp['JobId']
    logger.info(f"   Job ID: {job_id}")
    
    # Poll for completion
    blocks = []
    start_time = time.time()
    poll_count = 0
    
    while True:
        elapsed = time.time() - start_time
        if elapsed > max_wait_seconds:
            raise Exception(f"Textract job timed out after {max_wait_seconds} seconds")
        
        resp = textract.get_document_analysis(JobId=job_id)
        status = resp.get("JobStatus")
        poll_count += 1
        
        if status == "SUCCEEDED":
            blocks.extend(resp.get("Blocks", []))
            
            # Handle pagination
            next_token = resp.get("NextToken")
            page_count = 1
            while next_token:
                page_count += 1
                resp = textract.get_document_analysis(JobId=job_id, NextToken=next_token)
                blocks.extend(resp.get("Blocks", []))
                next_token = resp.get("NextToken")
            
            logger.info(f"✅ Textract job completed!")
            logger.info(f"   Time elapsed: {elapsed:.1f}s")
            logger.info(f"   Polls: {poll_count}")
            logger.info(f"   Pages: {page_count}")
            logger.info(f"   Total blocks: {len(blocks)}")
            
            # Log block type breakdown
            block_types = {}
            for b in blocks:
                bt = b.get('BlockType', 'UNKNOWN')
                block_types[bt] = block_types.get(bt, 0) + 1
            logger.info(f"   Block breakdown: {json.dumps(block_types)}")
            
            break
            
        elif status in ("IN_PROGRESS", "PARTIAL_SUCCESS"):
            logger.debug(f"   Polling... Status: {status} (elapsed: {elapsed:.1f}s)")
            time.sleep(2)  # Wait 2 seconds before polling again
            continue
        else:
            # FAILED or other status
            raise Exception(f"Textract job failed with status: {status}")
    
    return blocks


def parse_document_with_textract(file_obj, filename):
    """
    Main function to parse a document using AWS Textract.
    
    Args:
        file_obj: File-like object (image or PDF)
        filename: Original filename
        
    Returns:
        dict: Structured data with lines, key_values, and tables
    """
    logger.info("="*60)
    logger.info("🚀 STARTING TEXTRACT DOCUMENT PARSING")
    logger.info(f"   Filename: {filename}")
    logger.info("="*60)
    
    # Upload to S3
    s3_key = upload_to_s3(file_obj, filename)
    
    try:
        # Run Textract analysis
        blocks = run_textract_analysis(s3_key)
        
        # Convert to structured format
        logger.info("")
        logger.info("📊 PARSING TEXTRACT BLOCKS...")
        structured = blocks_to_structured(blocks)
        
        # Log the structured output
        logger.info("")
        logger.info("="*60)
        logger.info("📝 TEXTRACT PARSING RESULTS")
        logger.info("="*60)
        
        # Log lines found
        logger.info(f"\n📄 TEXT LINES ({len(structured['lines'])} found):")
        for i, line in enumerate(structured['lines'][:30]):  # First 30 lines
            logger.info(f"   {i+1:3d}. {line}")
        if len(structured['lines']) > 30:
            logger.info(f"   ... and {len(structured['lines']) - 30} more lines")
        
        # Log key-value pairs
        logger.info(f"\n🔑 KEY-VALUE PAIRS ({len(structured['key_values'])} found):")
        for key, value in structured['key_values'].items():
            logger.info(f"   '{key}' → '{value}'")
        
        # Log tables
        logger.info(f"\n📋 TABLES ({len(structured['tables'])} found):")
        for t_idx, table in enumerate(structured['tables']):
            logger.info(f"\n   TABLE {t_idx + 1} ({len(table)} rows × {len(table[0]) if table else 0} cols):")
            for r_idx, row in enumerate(table[:15]):  # First 15 rows
                row_str = " | ".join(str(cell)[:25] for cell in row)
                logger.info(f"      Row {r_idx + 1}: {row_str}")
            if len(table) > 15:
                logger.info(f"      ... and {len(table) - 15} more rows")
        
        logger.info("")
        logger.info("="*60)
        logger.info("✅ TEXTRACT PARSING COMPLETE")
        logger.info("="*60)
        
        return structured
        
    finally:
        # Always cleanup S3
        delete_from_s3(s3_key)
