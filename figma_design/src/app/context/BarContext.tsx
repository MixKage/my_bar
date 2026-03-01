import React, { createContext, useContext, useState, ReactNode } from "react";

interface BarContextType {
  selectedIngredients: Set<string>;
  toggleIngredient: (id: string) => void;
}

const BarContext = createContext<BarContextType | undefined>(undefined);

export const BarProvider = ({ children }: { children: ReactNode }) => {
  const [selectedIngredients, setSelectedIngredients] = useState<Set<string>>(
    new Set()
  );

  const toggleIngredient = (id: string) => {
    setSelectedIngredients((prev) => {
      const newSet = new Set(prev);
      if (newSet.has(id)) {
        newSet.delete(id);
      } else {
        newSet.add(id);
      }
      return newSet;
    });
  };

  return (
    <BarContext.Provider value={{ selectedIngredients, toggleIngredient }}>
      {children}
    </BarContext.Provider>
  );
};

export const useBar = () => {
  const context = useContext(BarContext);
  if (!context) {
    throw new Error("useBar must be used within BarProvider");
  }
  return context;
};
