import React, { createContext, useContext, useState, ReactNode } from 'react';
import { AnalyseScreen } from '../screens/AnalyseScreen';

interface AnalyseModalContextType {
  showModal: () => void;
  hideModal: () => void;
}

const AnalyseModalContext = createContext<AnalyseModalContextType | undefined>(undefined);

export function AnalyseModalProvider({ children }: { children: ReactNode }) {
  const [visible, setVisible] = useState(false);

  const showModal = () => setVisible(true);
  const hideModal = () => setVisible(false);

  return (
    <AnalyseModalContext.Provider value={{ showModal, hideModal }}>
      {children}
      <AnalyseScreen visible={visible} onClose={hideModal} />
    </AnalyseModalContext.Provider>
  );
}

export function useAnalyseModal() {
  const context = useContext(AnalyseModalContext);
  if (context === undefined) {
    throw new Error('useAnalyseModal must be used within an AnalyseModalProvider');
  }
  return context;
}

