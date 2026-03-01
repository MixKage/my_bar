import { useState } from "react";
import { Search, Check } from "lucide-react";
import { ingredients } from "../data/barData";
import { useBar } from "../context/BarContext";
import { Navigation } from "../components/Navigation";

export const BarInventory = () => {
  const [searchQuery, setSearchQuery] = useState("");
  const { selectedIngredients, toggleIngredient } = useBar();

  const filteredIngredients = ingredients.filter((ingredient) =>
    ingredient.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900/20 to-black text-white pb-24">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent drop-shadow-[0_0_15px_rgba(168,85,247,0.5)]">
            Мой Бар
          </h1>
          <p className="text-gray-400">Выберите ингредиенты, которые у вас есть</p>
        </div>

        {/* Search Bar */}
        <div className="mb-8 relative group">
          <div className="absolute inset-0 bg-purple-500/20 rounded-2xl blur-xl group-hover:bg-purple-500/30 transition-all duration-300" />
          <div className="relative flex items-center bg-black/50 backdrop-blur-xl rounded-2xl border border-purple-500/30 px-4 py-3 group-hover:border-purple-500/50 transition-all duration-300">
            <Search className="w-5 h-5 text-purple-400 mr-3" />
            <input
              type="text"
              placeholder="Поиск ингредиентов..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="flex-1 bg-transparent outline-none text-white placeholder-gray-500"
            />
          </div>
        </div>

        {/* Ingredients Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredIngredients.map((ingredient) => {
            const isSelected = selectedIngredients.has(ingredient.id);
            return (
              <button
                key={ingredient.id}
                onClick={() => toggleIngredient(ingredient.id)}
                className="group relative overflow-hidden rounded-2xl transition-all duration-300 hover:scale-105"
              >
                {/* Glow Effect */}
                <div
                  className={`absolute inset-0 blur-xl transition-all duration-300 ${
                    isSelected
                      ? "bg-purple-500/40"
                      : "bg-purple-500/0 group-hover:bg-purple-500/20"
                  }`}
                />

                {/* Card */}
                <div
                  className={`relative bg-black/50 backdrop-blur-xl border rounded-2xl overflow-hidden transition-all duration-300 ${
                    isSelected
                      ? "border-purple-500/70"
                      : "border-purple-500/20 group-hover:border-purple-500/40"
                  }`}
                >
                  {/* Image */}
                  <div className="relative h-32 overflow-hidden">
                    <img
                      src={ingredient.image}
                      alt={ingredient.name}
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />

                    {/* Check Badge */}
                    {isSelected && (
                      <div className="absolute top-3 right-3 w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center shadow-[0_0_20px_rgba(168,85,247,0.8)]">
                        <Check className="w-5 h-5 text-white" />
                      </div>
                    )}
                  </div>

                  {/* Content */}
                  <div className="p-4">
                    <h3 className="font-semibold text-lg mb-1">{ingredient.name}</h3>
                    <p className="text-sm text-purple-300">{ingredient.category}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </div>

        {filteredIngredients.length === 0 && (
          <div className="text-center py-16">
            <p className="text-gray-500 text-lg">Ингредиенты не найдены</p>
          </div>
        )}
      </div>

      <Navigation />
    </div>
  );
};
