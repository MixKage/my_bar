import { Link, useLocation } from "react-router";
import { Wine, Menu } from "lucide-react";

export const Navigation = () => {
  const location = useLocation();

  const navItems = [
    { path: "/", label: "Сырой бар", icon: Wine },
    { path: "/menu", label: "Барная карта", icon: Menu },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-black/80 backdrop-blur-xl border-t border-purple-500/30">
      <div className="max-w-7xl mx-auto px-4">
        <div className="flex items-center justify-around">
          {navItems.map(({ path, label, icon: Icon }) => {
            const isActive = location.pathname === path;
            return (
              <Link
                key={path}
                to={path}
                className={`flex flex-col items-center py-3 px-6 transition-all duration-300 relative ${
                  isActive
                    ? "text-purple-400"
                    : "text-gray-400 hover:text-purple-300"
                }`}
              >
                {isActive && (
                  <div className="absolute inset-0 bg-purple-500/10 rounded-lg blur-xl" />
                )}
                <Icon
                  className={`w-6 h-6 mb-1 transition-all duration-300 ${
                    isActive ? "drop-shadow-[0_0_8px_rgba(168,85,247,0.8)]" : ""
                  }`}
                />
                <span className="text-xs font-medium">{label}</span>
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
};