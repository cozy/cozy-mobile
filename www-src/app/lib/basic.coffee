b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
b64_enc = (data) ->

    return data unless data

    # var o1, o2, o3, h1, h2, h3, h4, bits, i = 0, ac = 0, enc="", tmp_arr = [];

    i = 0
    ac = 0
    out = []
    while i < data.length
        o1 = data.charCodeAt i++
        o2 = data.charCodeAt i++
        o3 = data.charCodeAt i++

        bits = o1<<16 | o2<<8 | o3

        h1 = bits>>18 & 0x3f
        h2 = bits>>12 & 0x3f
        h3 = bits>>6 & 0x3f
        h4 = bits & 0x3f

        out[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4)

    out = out.join('')

    switch data.length % 3
        when 1 then out = out.slice(0, -2) + '==';
        when 2 then out = out.slice(0, -1) + '=';

    return out

module.exports = (user, pass) ->
    'Basic ' + b64_enc(user + ':' + pass)