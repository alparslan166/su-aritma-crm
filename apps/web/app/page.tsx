"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { apiClient, Admin } from "@/lib/api";

export default function HomePage() {
  const router = useRouter();
  const [admins, setAdmins] = useState<Admin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    // Check if logged in
    if (typeof window !== "undefined" && !localStorage.getItem("admin_token")) {
      router.push("/login");
      return;
    }

    loadAdmins();
  }, [router]);

  const loadAdmins = async () => {
    try {
      setLoading(true);
      const response = await apiClient.getAllAdmins();
      if (response.success) {
        setAdmins(response.data);
      }
    } catch (err: any) {
      setError(err.message || "Adminler yüklenemedi");
      if (err.message?.includes("Unauthorized") || err.message?.includes("401")) {
        router.push("/login");
      }
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`${name} adlı admini silmek istediğinize emin misiniz?`)) {
      return;
    }

    try {
      await apiClient.deleteAdmin(id);
      await loadAdmins();
    } catch (err: any) {
      alert(err.message || "Admin silinemedi");
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "trial":
        return "bg-yellow-100 text-yellow-800";
      case "active":
        return "bg-green-100 text-green-800";
      case "expired":
        return "bg-red-100 text-red-800";
      default:
        return "bg-gray-100 text-gray-800";
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("tr-TR", {
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  };

  const handleLogout = () => {
    apiClient.logout();
    router.push("/login");
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg">Yükleniyor...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">
                Su Arıtma CRM - Ana Admin Paneli
          </h1>
            </div>
            <div className="flex items-center">
              <button
                onClick={handleLogout}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Çıkış Yap
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {error && (
            <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
              {error}
            </div>
          )}

          <div className="bg-white shadow overflow-hidden sm:rounded-md">
            <div className="px-4 py-5 sm:px-6">
              <h2 className="text-lg font-medium text-gray-900">Adminler</h2>
              <p className="mt-1 text-sm text-gray-500">
                Tüm adminleri görüntüleyin ve yönetin
              </p>
            </div>

            {admins.length === 0 ? (
              <div className="px-4 py-5 sm:px-6 text-center text-gray-500">
                Henüz admin bulunmuyor
              </div>
            ) : (
              <ul className="divide-y divide-gray-200">
                {admins.map((admin) => (
                  <li key={admin.id}>
                    <Link
                      href={`/admin/${admin.id}`}
                      className="block hover:bg-gray-50 transition-colors"
                    >
                      <div className="px-4 py-4 sm:px-6">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center">
                            <div className="flex-shrink-0">
                              <div className="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center">
                                <span className="text-blue-600 font-medium">
                                  {admin.name.charAt(0).toUpperCase()}
                                </span>
                              </div>
                            </div>
                            <div className="ml-4">
                              <div className="flex items-center">
                                <p className="text-sm font-medium text-gray-900">
                                  {admin.name}
                                </p>
                                {admin.role === "ANA" && (
                                  <span className="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                                    ANA
                                  </span>
                                )}
                              </div>
                              <p className="text-sm text-gray-500">{admin.email}</p>
                              <p className="text-xs text-gray-400">
                                {admin.adminId && `ID: ${admin.adminId}`}
          </p>
        </div>
                          </div>
                          <div className="flex items-center space-x-4">
                            <div className="text-right">
                              {admin.subscription && (
                                <span
                                  className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(
                                    admin.subscription.status,
                                  )}`}
                                >
                                  {admin.subscription.status === "trial"
                                    ? "Deneme"
                                    : admin.subscription.status === "active"
                                      ? "Aktif"
                                      : "Süresi Dolmuş"}
                                </span>
                              )}
                              <p className="text-xs text-gray-500 mt-1">
                                {formatDate(admin.createdAt)}
                              </p>
                            </div>
                            {admin.role !== "ANA" && (
                              <button
                                onClick={(e) => {
                                  e.preventDefault();
                                  e.stopPropagation();
                                  handleDelete(admin.id, admin.name);
                                }}
                                className="text-red-600 hover:text-red-900 text-sm font-medium"
                              >
                                Sil
                              </button>
                            )}
                          </div>
                        </div>
                      </div>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
