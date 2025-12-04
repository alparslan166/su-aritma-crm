const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

export interface Admin {
  id: string;
  adminId: string | null;
  name: string;
  email: string;
  phone: string;
  role: "ANA" | "ALT";
  status: string;
  emailVerified: boolean;
  createdAt: string;
  updatedAt: string;
  subscription?: {
    id: string;
    planType: string;
    status: string;
    startDate: string;
    endDate: string;
    trialEnds: string | null;
  };
}

export interface AdminDetail extends Admin {
  _count: {
    personnel: number;
    customers: number;
    jobs: number;
    inventoryItems: number;
  };
}

export interface LoginResponse {
  success: boolean;
  data: {
    id: string;
    name: string;
    role: string;
  };
}

class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    if (typeof window !== "undefined") {
      this.token = localStorage.getItem("admin_token");
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const headers: HeadersInit = {
      "Content-Type": "application/json",
      ...options.headers,
    };

    if (this.token) {
      headers["x-admin-id"] = this.token;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: "Unknown error" }));
      throw new Error(error.message || `HTTP error! status: ${response.status}`);
    }

    return response.json();
  }

  async login(email: string, password: string): Promise<LoginResponse> {
    const response = await this.request<LoginResponse>("/auth/login", {
      method: "POST",
      body: JSON.stringify({
        identifier: email,
        password,
        role: "admin",
      }),
    });

    if (response.success && typeof window !== "undefined") {
      localStorage.setItem("admin_token", response.data.id);
      this.token = response.data.id;
    }

    return response;
  }

  logout() {
    if (typeof window !== "undefined") {
      localStorage.removeItem("admin_token");
      this.token = null;
    }
  }

  async getAllAdmins(): Promise<{ success: boolean; data: Admin[] }> {
    return this.request("/admins");
  }

  async getAdminById(id: string): Promise<{ success: boolean; data: AdminDetail }> {
    return this.request(`/admins/${id}`);
  }

  async deleteAdmin(id: string): Promise<{ success: boolean; message: string }> {
    return this.request(`/admins/${id}`, {
      method: "DELETE",
    });
  }
}

export const apiClient = new ApiClient(API_BASE_URL);

