"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import Link from "next/link";
import { apiClient, AdminDetail } from "@/lib/api";

export default function AdminDetailPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  const [admin, setAdmin] = useState<AdminDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (typeof window !== "undefined" && !localStorage.getItem("admin_token")) {
      router.push("/login");
      return;
    }

    loadAdmin();
  }, [id, router]);

  const loadAdmin = async () => {
    try {
      setLoading(true);
      const response = await apiClient.getAdminById(id);
      if (response.success) {
        setAdmin(response.data);
      }
    } catch (err: any) {
      setError(err.message || "Admin bilgileri yüklenemedi");
      if (err.message?.includes("Unauthorized") || err.message?.includes("401")) {
        router.push("/login");
      }
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!admin) return;
    
    if (!confirm(`${admin.name} adlı admini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.`)) {
      return;
    }

    try {
      await apiClient.deleteAdmin(id);
      router.push("/");
    } catch (err: any) {
      alert(err.message || "Admin silinemedi");
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("tr-TR", {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
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

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg">Yükleniyor...</div>
      </div>
    );
  }

  if (!admin) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-lg text-red-600">{error || "Admin bulunamadı"}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Link href="/" className="text-blue-600 hover:text-blue-800">
                ← Geri
              </Link>
            </div>
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">Admin Detayı</h1>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:px-6">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg leading-6 font-medium text-gray-900">
                    {admin.name}
                  </h3>
                  <p className="mt-1 max-w-2xl text-sm text-gray-500">
                    {admin.email}
                  </p>
                </div>
                {admin.role === "ANA" ? (
                  <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
                    ANA Admin
                  </span>
                ) : (
                  <button
                    onClick={handleDelete}
                    className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
                  >
                    Admini Sil
                  </button>
                )}
              </div>
            </div>

            <div className="border-t border-gray-200">
              <dl>
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Telefon</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {admin.phone}
                  </dd>
                </div>
                <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Admin ID</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {admin.adminId || "Yok"}
                  </dd>
                </div>
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Durum</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${admin.status === "active" ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-800"}`}>
                      {admin.status}
                    </span>
                  </dd>
                </div>
                <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">E-posta Doğrulandı</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {admin.emailVerified ? (
                      <span className="text-green-600">✓ Evet</span>
                    ) : (
                      <span className="text-red-600">✗ Hayır</span>
                    )}
                  </dd>
                </div>
                {admin.subscription && (
                  <>
                    <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                      <dt className="text-sm font-medium text-gray-500">Abonelik Durumu</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(admin.subscription.status)}`}>
                          {admin.subscription.status === "trial" ? "Deneme" : admin.subscription.status === "active" ? "Aktif" : "Süresi Dolmuş"}
                        </span>
                      </dd>
                    </div>
                    <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                      <dt className="text-sm font-medium text-gray-500">Plan Tipi</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                        {admin.subscription.planType === "monthly" ? "Aylık" : "Yıllık"}
                      </dd>
                    </div>
                    <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                      <dt className="text-sm font-medium text-gray-500">Başlangıç Tarihi</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                        {formatDate(admin.subscription.startDate)}
                      </dd>
                    </div>
                    <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                      <dt className="text-sm font-medium text-gray-500">Bitiş Tarihi</dt>
                      <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                        {formatDate(admin.subscription.endDate)}
                      </dd>
                    </div>
                    {admin.subscription.trialEnds && (
                      <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                        <dt className="text-sm font-medium text-gray-500">Deneme Bitiş Tarihi</dt>
                        <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                          {formatDate(admin.subscription.trialEnds)}
                        </dd>
                      </div>
                    )}
                  </>
                )}
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">İstatistikler</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    <div className="grid grid-cols-2 gap-4 mt-2">
                      <div>
                        <span className="font-medium">Personel:</span> {admin._count.personnel}
                      </div>
                      <div>
                        <span className="font-medium">Müşteri:</span> {admin._count.customers}
                      </div>
                      <div>
                        <span className="font-medium">İş:</span> {admin._count.jobs}
                      </div>
                      <div>
                        <span className="font-medium">Stok:</span> {admin._count.inventoryItems}
                      </div>
                    </div>
                  </dd>
                </div>
                <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Oluşturulma Tarihi</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {formatDate(admin.createdAt)}
                  </dd>
                </div>
                <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt className="text-sm font-medium text-gray-500">Son Güncelleme</dt>
                  <dd className="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                    {formatDate(admin.updatedAt)}
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

