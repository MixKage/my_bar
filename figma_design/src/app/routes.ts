import { createBrowserRouter } from "react-router";
import { BarInventory } from "./pages/BarInventory";
import { BarMenu } from "./pages/BarMenu";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: BarInventory,
  },
  {
    path: "/menu",
    Component: BarMenu,
  },
]);
