module.exports = (url) ->
    # add .cozycloud.cc if the user only input name
    if url.indexOf('.') is -1 and url.length > 0
        url = url + ".cozycloud.cc"

    # Add http on the hostname
    if url[0..3] isnt 'http'
        url = 'https://' + url

    # remove trailing slash
    if url[url.length-1] is '/'
        url = url[..-2]

    return url
