package docspell.common

import cats.implicits._
import scala.concurrent.duration.{FiniteDuration, Duration => SDur}
import java.time.{Duration => JDur}
import java.util.concurrent.TimeUnit

import cats.effect.Sync

case class Duration(nanos: Long) {

  def millis: Long = nanos / 1000000

  def seconds: Long = millis / 1000

  def toScala: FiniteDuration =
    FiniteDuration(nanos, TimeUnit.NANOSECONDS)

  def toJava: JDur =
    JDur.ofNanos(nanos)

  def formatExact: String =
    s"$millis ms"
}

object Duration {

  def apply(d: SDur): Duration =
    Duration(d.toNanos)

  def apply(d: JDur): Duration =
    Duration(d.toNanos)

  def seconds(n: Long): Duration =
    apply(JDur.ofSeconds(n))

  def millis(n: Long): Duration =
    apply(JDur.ofMillis(n))

  def minutes(n: Long): Duration =
    apply(JDur.ofMinutes(n))

  def hours(n: Long): Duration =
    apply(JDur.ofHours(n))

  def nanos(n: Long): Duration =
    Duration(n)

  def stopTime[F[_]: Sync]: F[F[Duration]] =
    for {
      now <- Timestamp.current[F]
      end = Timestamp.current[F]
    } yield end.map(e => Duration.millis(e.toMillis - now.toMillis))
}
