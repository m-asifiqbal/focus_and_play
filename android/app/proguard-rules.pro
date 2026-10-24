# R8 rules for the release build.
#
# Why: release builds shrink with R8 in *full mode*, which no longer keeps a
# class's constructors just because the class itself is kept. Google Mobile Ads
# pulls in an older WorkManager whose consumer rules rely on that, so R8 removed
# the no-arg constructor of Room's generated WorkDatabase_Impl and the app
# crashed at launch, before Flutter started:
#   "Unable to get provider androidx.startup.InitializationProvider ...
#    Failed to create an instance of androidx.work.impl.WorkDatabase"

# Room databases are created by reflection through their no-arg constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# WorkManager instantiates these by class name as well.
-keep class * extends androidx.work.InputMerger { <init>(); }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# flutter_local_notifications stores scheduled reminders with Gson, which needs
# generic signatures (TypeToken) at runtime to read them back, e.g. after a reboot.
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
