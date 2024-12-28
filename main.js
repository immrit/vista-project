const fs = require('fs');
const { Client, Databases, ID } = require('node-appwrite');
const csv = require('csv-parser');

// تنظیمات کلاینت Appwrite
const client = new Client();
client
  .setEndpoint('http://45.150.32.75:9865/v1') // آدرس سرور Appwrite
  .setProject('675605fc0007545481a2') // آیدی پروژه
  .setKey('YOUR_API_KEY'); // کلید API

const databases = new Databases(client);

async function importCsvData() {
  const filePath = 'http://45.150.32.75:9865/v1/storage/buckets/avatars/files/675adad500126856792e/view?project=675605fc0007545481a2&project=675605fc0007545481a2&mode=admin'; // مسیر فایل CSV

  // خواندن فایل CSV
  const profiles = [];
  fs.createReadStream(filePath)
    .pipe(csv())
    .on('data', (row) => {
      profiles.push(row);
    })
    .on('end', async () => {
      console.log('CSV file successfully processed.');

      // آپلود داده‌ها به Appwrite
      for (const profile of profiles) {
        try {
          await databases.createDocument(
            'vista_db', // آیدی دیتابیس
            'profiles', // آیدی کالکشن profiles
            ID.unique(),
            {
              username: profile['username'],
              email: profile['email'],
              avatar_url: profile['avatar_url'],
              created_at: profile['created_at'],
            }
          );
          console.log(`Uploaded profile: ${profile['username']}`);
        } catch (error) {
          console.error(`Failed to upload profile: ${profile['username']}`, error);
        }
      }
    });
}

// اجرای تابع
importCsvData();
