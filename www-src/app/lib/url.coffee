a = document.createElement('a')
module.exports = (url)  ->
    a.href = url
    return result =
        host: a.host
        hostname: a.hostname
        pathname: a.pathname
        port: a.port
        protocol: a.protocol
        search: a.search
        hash: a.hash