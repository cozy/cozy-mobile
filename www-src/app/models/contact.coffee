
Contact = {}

module.exports = Contact

# From cordova to cozy
# from cozy to cordova

Contact.cozy2Cordova = (cozyContact) ->
    # Helpers :
    n2ContactName = (n) ->
        parts =  n.split ';'
        [familyName, givenName, middle, prefix, suffix] = parts

        # Cf cozy-vCard.nToFN :
        validParts = parts.filter (part) -> part? and part isnt ''
        formatted = validParts.join ' '

        return new ContactName formatted, familyName, givenName,
                                middle, prefix, suffix

    cozyContact2ContactOrganizations = (contact) ->
        if contact.org
            return [
                new ContactOrganization
                    false, # pref field
                    null, # TODO type
                    contact.org, # TODO check name <-> org.
                    contact.department,
                    contact.title
                ]
            # TODO : look into datapoints!
        else
            return []

    cozyContact2URLs = (contact) ->
        if contact.url
            return [
                new ContactField 'urls',    contact.url, false
                ]
        # TODO : look into datapoints!
        else
            return []

    tags2Categories = (tags) ->
        if tags
            return tags.map (tag) ->
                return new ContactField 'categories', tag, false # TODO pref
        else
            return []

    attachments2Photos = (contact) ->
        if contact._attachments? and 'picture' of contact._attachments
            console.log contact._attachments.picture
            photo = new ContactField 'base64', contact._attachments.picture.data

            return [photo]

        return [];


    c = navigator.contacts.create
            #TODO ? id || rawId :  id
            # vCard FullName = display name
            # (Prefix Given Middle Familly Suffix), or something else.
            displayName: cozyContact.fn
            # vCard Name = splitted
            # (Familly;Given;Middle;Prefix;Suffix)
            name: n2ContactName cozyContact.n
            organizations: cozyContact2ContactOrganizations cozyContact
            # Missing Cordova ; nickname ? cozyContact.title
            birthday: cozyContact.bday # check date format !
            nickname: cozyContact.nickname
            urls: cozyContact2URLs cozyContact
            #cozyContact.revision      : Date
            # TODO extract somes.cozyContact.datapoints    : [DataPoint]
            note: cozyContact.note
            categories: tags2Categories cozyContact.tags #
            photos: attachments2Photos cozyContact

    return c

Contact.cordova2Cozy = (cordovaContact, callback) ->
    contactName2N = (contactName) ->
        parts = []
        for field in ['familyName', 'givenName', 'middle', 'prefix', 'suffix']
            parts.push contactName[field] or ''

        return parts.join ';'






    c =
        docType: 'contact'
        #TODO ! id            : String
        # vCard FullName = display name
        # (Prefix Given Middle Familly Suffix), or something else.
        fn: cordovaContact.displayName
        # vCard Name = splitted
        # (Familly;Given;Middle;Prefix;Suffix)
        n: contactName2N cordovaContact.name
        #TODO in datapoints handling org:
        # title:
        # department:
        bday: cordovaContact.birthday
        nickname: cordovaContact.nickname
        # TODO in datapoints url:
        # TODO ? revision
        # TOTO datapoints
        note: cordovaContact.note
        # TODO !tags: cordovaContact.categories
        # _attachments: photos2Attachments cordovaContact.photos


    # photos2Attachments = (photos, cb) ->

    console.log 'photos2Attachments'
    unless cordovaContact.photos?.length > 0
        return callback null, c


    photo = cordovaContact.photos[0]
    console.log photo

    img = new Image()

    img.onload = ->
        IMAGE_DIMENSION = 600
        ratiodim = if img.width > img.height then 'height' else 'width'
        ratio = IMAGE_DIMENSION / img[ratiodim]

        # use canvas to resize the image
        canvas = document.createElement 'canvas'
        canvas.height = canvas.width = IMAGE_DIMENSION
        ctx = canvas.getContext '2d'
        ctx.drawImage img, 0, 0, ratio * img.width, ratio * img.height
        dataUrl = canvas.toDataURL 'image/jpeg'

        c._attachments =
            picture:
                # content_type: 'image/jpeg'
                content_type: 'application/octet-stream'
                data: dataUrl.split(',')[1]


        callback null, c

    img.src = photo.value

    # return c

