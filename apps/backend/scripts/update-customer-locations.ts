import { prisma } from "../src/lib/prisma";

async function updateCustomerLocations() {
  console.log("🔄 Updating customer locations from job locations...\n");

  try {
    // Tüm müşterileri al (location'ı olmayan veya boş olanlar)
    const customers = await prisma.customer.findMany({
      include: {
        jobs: {
          where: {
            location: { not: null },
          },
          orderBy: { createdAt: "desc" },
          take: 1, // En son işin location'ını kullan
        },
      },
    });

    if (customers.length === 0) {
      console.log("❌ No customers found.");
      return;
    }

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    for (const customer of customers) {
      try {
        // Eğer customer'ın zaten location'ı varsa ve geçerliyse, atla
        if (customer.location) {
          const location = customer.location as any;
          if (
            location &&
            typeof location.latitude === "number" &&
            typeof location.longitude === "number"
          ) {
            skipped++;
            continue;
          }
        }

        // Job location'ından location al
        if (customer.jobs.length > 0 && customer.jobs[0].location) {
          const jobLocation = customer.jobs[0].location as any;
          if (
            jobLocation &&
            (typeof jobLocation.latitude === "number" ||
              typeof jobLocation.lat === "number")
          ) {
            const latitude =
              jobLocation.latitude ?? jobLocation.lat;
            const longitude =
              jobLocation.longitude ?? jobLocation.lng;

            if (
              typeof latitude === "number" &&
              typeof longitude === "number"
            ) {
              await prisma.customer.update({
                where: { id: customer.id },
                data: {
                  location: {
                    latitude,
                    longitude,
                    address: jobLocation.address ?? customer.address,
                  },
                },
              });
              updated++;
              console.log(
                `  ✅ Updated customer ${customer.name} (${customer.id})`,
              );
              continue;
            }
          }
        }

        // Job location yoksa, location'ı null olarak işaretle (geocoding için)
        skipped++;
        console.log(
          `  ⏭️  Skipped customer ${customer.name} (${customer.id}) - no job location`,
        );
      } catch (error) {
        failed++;
        console.error(
          `  ❌ Failed to update customer ${customer.name} (${customer.id}):`,
          error,
        );
      }
    }

    console.log("\n✅ Customer location update completed!");
    console.log(`  - Updated: ${updated}`);
    console.log(`  - Skipped: ${skipped}`);
    console.log(`  - Failed: ${failed}`);
  } catch (error) {
    console.error("\n❌ Update failed:", error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

updateCustomerLocations()
  .catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });

