// A simple Scala script for parsing HOCON into fully resolved JSON
// Usage: hocon2json HOCON_FILE [DEFAULT_FILE...]
// 
// Earlier files have precendence over the later ones, i.e., later ones are
// fallback for the earlier ones.
//
// See: https://github.com/typesafehub/config/blob/master/HOCON.md#readme
// Author: Jaeho Shin <netj@cs.stanford.edu>
// Created: 2014-09-29

import java.io.File
import com.typesafe.config._

object HOCON2JSON {
def main(args: Array[String]): Unit = {

if (args.length < 1) {
    System.err.println("Usage: hocon2json HOCON_FILE [DEFAULT_FILE]")
    System.err.println("Input HOCON_FILE must be specified")
    System.exit(1)
}

val configResolveOptions = ConfigResolveOptions.defaults()
    .setUseSystemEnvironment(true)
    .setAllowUnresolved(false)

try {
    val defaults = (
        // support zero or more fallback/default files
        args.drop(1).foldLeft(ConfigFactory.empty()) { (c,arg) =>
            val f = new File(arg)
            if (!f.exists())
                throw new Exception(s"${arg}: Not found")
            c.withFallback(ConfigFactory.parseFile(f))
        }
    ).resolve(configResolveOptions)
    val config = ConfigFactory.parseFile(new File(args(0)))
        .withFallback(defaults)
        .resolve(configResolveOptions)
    config.checkValid(defaults) // TODO filter paths?
    println(config.root().render(ConfigRenderOptions.concise()
        .setFormatted(true))
    )
    System.exit(0)
} catch {
    case e: Throwable =>
        System.err.println(e.getMessage())
}
System.exit(2)

}
}
