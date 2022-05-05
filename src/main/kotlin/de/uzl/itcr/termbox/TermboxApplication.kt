package de.uzl.itcr.termbox

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class TermboxApplication

fun main(args: Array<String>) {
    runApplication<TermboxApplication>(*args)
}
