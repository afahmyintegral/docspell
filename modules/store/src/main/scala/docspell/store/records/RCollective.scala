package docspell.store.records

import docspell.common._
import docspell.store.impl.Column
import docspell.store.impl.Implicits._
import doobie._
import doobie.implicits._
import fs2.Stream

case class RCollective(id: Ident, state: CollectiveState, language: Language, created: Timestamp)

object RCollective {

  val table = fr"collective"

  object Columns {

    val id       = Column("cid")
    val state    = Column("state")
    val language = Column("doclang")
    val created  = Column("created")

    val all = List(id, state, language, created)
  }

  import Columns._

  def insert(value: RCollective): ConnectionIO[Int] = {
    val sql = insertRow(
      table,
      Columns.all,
      fr"${value.id},${value.state},${value.language},${value.created}"
    )
    sql.update.run
  }

  def update(value: RCollective): ConnectionIO[Int] = {
    val sql = updateRow(
      table,
      id.is(value.id),
      commas(
        state.setTo(value.state)
      )
    )
    sql.update.run
  }

  def findLanguage(cid: Ident): ConnectionIO[Option[Language]] =
    selectSimple(List(language), table, id.is(cid)).query[Option[Language]].unique

  def updateLanguage(cid: Ident, lang: Language): ConnectionIO[Int] =
    updateRow(table, id.is(cid), language.setTo(lang)).update.run

  def findById(cid: Ident): ConnectionIO[Option[RCollective]] = {
    val sql = selectSimple(all, table, id.is(cid))
    sql.query[RCollective].option
  }

  def existsById(cid: Ident): ConnectionIO[Boolean] = {
    val sql = selectCount(id, table, id.is(cid))
    sql.query[Int].unique.map(_ > 0)
  }

  def findAll(order: Columns.type => Column): ConnectionIO[Vector[RCollective]] = {
    val sql = selectSimple(all, table, Fragment.empty) ++ orderBy(order(Columns).f)
    sql.query[RCollective].to[Vector]
  }

  def streamAll(order: Columns.type => Column): Stream[ConnectionIO, RCollective] = {
    val sql = selectSimple(all, table, Fragment.empty) ++ orderBy(order(Columns).f)
    sql.query[RCollective].stream
  }
}
