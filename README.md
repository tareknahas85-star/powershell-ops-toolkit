# PowerShell Ops Toolkit

Small PowerShell scripts for the jobs a server person does again and again.

---

## In English

Every script here does one job, prints a clear result, and does not change anything on your system unless its name says so. You can run them one by one, or put them in Task Scheduler and forget about them.

### The scripts

| Script | What it does |
|---|---|
| `Get-ServerHealth.ps1` | Checks disk space, memory, uptime and services, and tells you what is wrong |
| `Backup-Folders.ps1` | Copies folders to a backup place, keeps a log, and deletes backups that are too old |
| `Get-CertificateExpiry.ps1` | Tells you how many days are left before a website certificate expires |
| `Test-Endpoints.ps1` | Opens a list of web addresses and tells you which ones are down or slow |
| `Get-DiskCleanupReport.ps1` | Finds the biggest files and folders eating your disk |

### How to run one

```powershell
.\Get-ServerHealth.ps1
```

Every script accepts `-Help` style parameters. To see what a script takes:

```powershell
Get-Help .\Get-ServerHealth.ps1 -Full
```

### Running them on a schedule

All the scripts can write their result to a file with `-OutputPath`. So you can run one every morning and read it later:

```powershell
.\Get-ServerHealth.ps1 -OutputPath "C:\Reports\health.html"
```

Then in Task Scheduler make a task that runs:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-ServerHealth.ps1" -OutputPath "C:\Reports\health.html"
```

### Before you run them

- You need PowerShell 5.1 or PowerShell 7.
- Some checks need admin rights. The script tells you if it needs them.
- `Backup-Folders.ps1` is the only script that writes files outside its own log. Read its settings before the first run.

### A note on safety

Nothing here deletes anything by surprise. `Backup-Folders.ps1` only deletes old backup copies it made itself, and only when you turn that on with `-KeepDays`. Every script supports `-WhatIf` where it makes sense, so you can see what would happen before it happens.

---

## بالعربي

كل سكربت هنا يقوم بمهمة واحدة، ويطبع نتيجة واضحة، ولا يغيّر شيئاً على جهازك إلا إذا كان اسمه يقول ذلك. تستطيع تشغيلها واحداً واحداً، أو وضعها في مجدول المهام ونسيانها.

### السكربتات

| السكربت | ماذا يفعل |
|---|---|
| `Get-ServerHealth.ps1` | يفحص مساحة القرص والذاكرة ومدة التشغيل والخدمات، ويخبرك ما الذي فيه مشكلة |
| `Backup-Folders.ps1` | ينسخ المجلدات إلى مكان النسخ الاحتياطي، ويحفظ سجلاً، ويحذف النسخ القديمة جداً |
| `Get-CertificateExpiry.ps1` | يخبرك كم يوماً بقي قبل انتهاء شهادة الموقع |
| `Test-Endpoints.ps1` | يفتح قائمة من المواقع ويخبرك أيّها متوقف أو بطيء |
| `Get-DiskCleanupReport.ps1` | يجد أكبر الملفات والمجلدات التي تأكل مساحة قرصك |

### كيف تشغّل واحداً

```powershell
.\Get-ServerHealth.ps1
```

ولمعرفة ما يقبله أي سكربت من إعدادات:

```powershell
Get-Help .\Get-ServerHealth.ps1 -Full
```

### تشغيلها بشكل تلقائي

كل السكربتات تستطيع كتابة نتيجتها في ملف عبر `-OutputPath`. فتستطيع تشغيل واحد كل صباح وقراءة النتيجة لاحقاً:

```powershell
.\Get-ServerHealth.ps1 -OutputPath "C:\Reports\health.html"
```

ثم في مجدول المهام (Task Scheduler) أنشئ مهمة تشغّل:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-ServerHealth.ps1" -OutputPath "C:\Reports\health.html"
```

### قبل أن تشغّلها

- تحتاج PowerShell إصدار 5.1 أو PowerShell 7.
- بعض الفحوصات تحتاج صلاحيات مدير. والسكربت يخبرك إذا كان يحتاجها.
- `Backup-Folders.ps1` هو السكربت الوحيد الذي يكتب ملفات خارج سجلّه. اقرأ إعداداته قبل التشغيل الأول.

### ملاحظة عن الأمان

لا شيء هنا يحذف شيئاً بشكل مفاجئ. `Backup-Folders.ps1` يحذف فقط النسخ القديمة التي صنعها هو بنفسه، وفقط عندما تشغّل ذلك بـ `-KeepDays`. وكل سكربت يدعم `-WhatIf` حيثما كان ذلك منطقياً، لترى ماذا سيحدث قبل أن يحدث.
