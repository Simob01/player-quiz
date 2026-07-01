# WorkManager initializes this Room database through reflection from AndroidX
# Startup before Flutter starts. Keep it intact for shrunk release builds.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
