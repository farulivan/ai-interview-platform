import api from "./api";
import type { HomeDesk } from "@/types/home";

export const homeApi = {
  get: () => api.get<HomeDesk>("/home"),
};
