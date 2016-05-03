module.exports = (options) -> new Logger options

LOG_SIZE = 1000

colors =
     blue: ['\x1B[34m', '\x1B[39m']
     cyan: ['\x1B[36m', '\x1B[39m']
     green: ['\x1B[32m', '\x1B[39m']
     magenta: ['\x1B[36m', '\x1B[39m']
     red: ['\x1B[31m', '\x1B[39m']
     yellow: ['\x1B[33m', '\x1B[39m']

levelColors =
    error: colors.red
    debug: colors.green
    warn: colors.yellow
    info: colors.blue

class Logger

    constructor: (@options) ->
        @options ?= {}
        if 'processusTag' of @options
            Logger.processusTag = @options.processusTag

        # If no localStorage, should be test environment : deactivate log.
        unless localStorage?
            @noLog = true


    stringify: (text) ->
        if text instanceof Error
            err = text
            text = err.message
            if err.stack?
                text += "\n" + err.stack
        else if text instanceof Object
            text = JSON.stringify text
        return text


    format: (level, texts) ->
        text = (@stringify text for text in texts).join(" ")
        text = "#{@options.prefix} | #{text}" if @options.prefix?
        text = "#{level} - #{text}" if level
        text = "#{Logger.processusTag}> #{text}" if Logger.processusTag
        if @options.date
            date = new Date().toISOString()
            text = "[#{date}] #{text}"
        return text

    info: (texts...) ->
        return if @noLog
        text = @format 'info', texts
        @persist text
        console.info text

    warn: (texts...) ->
        return if @noLog
        text = @format 'warn', texts
        @persist text
        console.warn text

    error: (texts...) ->
        return if @noLog
        text = @format 'error', texts
        @persist text
        console.error text

    debug: (texts...) ->
        return if @noLog
        text = @format 'debug', texts
        @persist text
        console.info text

    raw: (texts...) ->
        return if @noLog
        console.log.apply console, texts

    lineBreak: (text) ->
        return if @noLog
        text = Array(80).join("*")
        @raw text
        window.logTrace.push text

    persist: (text) ->
        logIndex = +localStorage.getItem "log_index"
        logIndex = (logIndex + 1) % LOG_SIZE
        localStorage.setItem "log_#{logIndex}", text
        localStorage.setItem "log_index", '' + logIndex

    getTraces: ->
        logIndex = +localStorage.getItem "log_index"
        i = (logIndex + 1) % LOG_SIZE

        traces = []
        while i != logIndex
            log = localStorage.getItem "log_#{i}"
            traces.push log if log
            i = (i + 1) % LOG_SIZE

        return traces
