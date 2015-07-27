libraryDependencies += "com.typesafe" % "config" % "1.2.1"  // XXX Java 8 is required for users if we use the next version 1.3.0

scalacOptions += "-target:jvm-1.6"

javacOptions ++= Seq("-source", "1.6")
