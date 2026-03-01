import { useState, useMemo } from "react";
import { Grid3x3, List, ChevronDown, ChevronUp } from "lucide-react";
import { cocktails } from "../data/barData";
import { useBar } from "../context/BarContext";
import { Navigation } from "../components/Navigation";

type ViewMode = "grid" | "list";

export const BarMenu = () => {
  const [viewMode, setViewMode] = useState<ViewMode>("list");
  const [expandedId, setExpandedId] = useState<string | null>(cocktails[0]?.id || null);
  const { selectedIngredients } = useBar();

  const availableCocktails = useMemo(() => {
    return cocktails.filter((cocktail) =>
      cocktail.ingredients.every((ing) => selectedIngredients.has(ing))
    );
  }, [selectedIngredients]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-pink-900/20 to-black text-white pb-24">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-pink-400 to-purple-400 bg-clip-text text-transparent drop-shadow-[0_0_15px_rgba(236,72,153,0.5)]">
              Барная карта
            </h1>
            <p className="text-gray-400">
              Доступно {availableCocktails.length} из {cocktails.length} коктейлей
            </p>
          </div>

          {/* View Toggle */}
          <div className="flex gap-2 bg-black/50 backdrop-blur-xl rounded-xl p-1 border border-pink-500/30">
            <button
              onClick={() => setViewMode("list")}
              className={`p-2 rounded-lg transition-all duration-300 ${
                viewMode === "list"
                  ? "bg-pink-500/20 text-pink-400 shadow-[0_0_15px_rgba(236,72,153,0.4)]"
                  : "text-gray-400 hover:text-pink-300"
              }`}
            >
              <List className="w-5 h-5" />
            </button>
            <button
              onClick={() => setViewMode("grid")}
              className={`p-2 rounded-lg transition-all duration-300 ${
                viewMode === "grid"
                  ? "bg-pink-500/20 text-pink-400 shadow-[0_0_15px_rgba(236,72,153,0.4)]"
                  : "text-gray-400 hover:text-pink-300"
              }`}
            >
              <Grid3x3 className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Grid View */}
        {viewMode === "grid" && (
          <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
            {availableCocktails.map((cocktail) => (
              <div
                key={cocktail.id}
                className="group relative overflow-hidden rounded-2xl transition-all duration-300 hover:scale-105"
              >
                {/* Glow Effect */}
                <div className="absolute inset-0 bg-pink-500/20 blur-xl group-hover:bg-pink-500/40 transition-all duration-300" />

                {/* Card */}
                <div className="relative bg-black/50 backdrop-blur-xl border border-pink-500/30 rounded-2xl overflow-hidden group-hover:border-pink-500/60 transition-all duration-300">
                  <div className="relative aspect-[3/4] overflow-hidden">
                    <img
                      src={cocktail.image}
                      alt={cocktail.name}
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black via-black/50 to-transparent" />

                    <div className="absolute bottom-0 left-0 right-0 p-4">
                      <h3 className="font-bold text-xl mb-1 drop-shadow-[0_0_10px_rgba(0,0,0,0.8)]">
                        {cocktail.name}
                      </h3>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* List View */}
        {viewMode === "list" && (
          <div className="space-y-4">
            {availableCocktails.map((cocktail) => {
              const isExpanded = expandedId === cocktail.id;
              return (
                <div
                  key={cocktail.id}
                  className="group relative overflow-hidden rounded-2xl transition-all duration-300"
                >
                  {/* Glow Effect */}
                  <div
                    className={`absolute inset-0 blur-xl transition-all duration-500 ${
                      isExpanded
                        ? "bg-pink-500/40"
                        : "bg-pink-500/10 group-hover:bg-pink-500/20"
                    }`}
                  />

                  {/* Card */}
                  <div
                    className={`relative bg-black/50 backdrop-blur-xl border rounded-2xl overflow-hidden transition-all duration-300 ${
                      isExpanded
                        ? "border-pink-500/70"
                        : "border-pink-500/20 group-hover:border-pink-500/40"
                    }`}
                  >
                    <button
                      onClick={() =>
                        setExpandedId(isExpanded ? null : cocktail.id)
                      }
                      className="w-full"
                    >
                      <div className="flex items-center p-4 gap-4">
                        {/* Thumbnail */}
                        <div className="relative w-20 h-20 rounded-xl overflow-hidden flex-shrink-0 border border-pink-500/30">
                          <img
                            src={cocktail.image}
                            alt={cocktail.name}
                            className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                          />
                        </div>

                        {/* Content */}
                        <div className="flex-1 text-left">
                          <h3 className="font-bold text-xl mb-1">
                            {cocktail.name}
                          </h3>
                          <p className="text-sm text-gray-400 line-clamp-1">
                            {cocktail.description}
                          </p>
                        </div>

                        {/* Expand Icon */}
                        <div className="text-pink-400">
                          {isExpanded ? (
                            <ChevronUp className="w-6 h-6" />
                          ) : (
                            <ChevronDown className="w-6 h-6" />
                          )}
                        </div>
                      </div>

                      {/* Expanded Content */}
                      {isExpanded && (
                        <div className="border-t border-pink-500/20 p-6 animate-in fade-in slide-in-from-top-2 duration-300">
                          <div className="grid md:grid-cols-2 gap-6">
                            {/* Large Image */}
                            <div className="relative aspect-[4/5] rounded-xl overflow-hidden border border-pink-500/30">
                              <img
                                src={cocktail.image}
                                alt={cocktail.name}
                                className="w-full h-full object-cover"
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                            </div>

                            {/* Recipe Details */}
                            <div>
                              <h4 className="text-2xl font-bold mb-4 text-pink-400">
                                Состав
                              </h4>
                              <p className="text-gray-300 leading-relaxed">
                                {cocktail.description}
                              </p>

                              <div className="mt-6 p-4 bg-pink-500/10 rounded-xl border border-pink-500/30">
                                <p className="text-sm text-gray-400">
                                  Все необходимые ингредиенты в наличии
                                </p>
                              </div>
                            </div>
                          </div>
                        </div>
                      )}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {availableCocktails.length === 0 && (
          <div className="text-center py-16">
            <p className="text-gray-500 text-lg mb-2">
              Недостаточно ингредиентов
            </p>
            <p className="text-gray-600 text-sm">
              Добавьте ингредиенты в "Сыром баре" чтобы увидеть доступные коктейли
            </p>
          </div>
        )}
      </div>

      <Navigation />
    </div>
  );
};
