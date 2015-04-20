
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
                new ContactOrganization false, null, contact.org
                , contact.department, contact.title
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

    dataPoints2Cordova = (cozyContact, cordovaContact) ->
        addContactField = (cordovaField, datapoint) ->
            unless cordovaContact[cordovaField]
                cordovaContact[cordovaField] = []

            field = new ContactField datapoint.type, datapoint.value
            cordovaContact[cordovaField].push field



        for i, datapoint of cozyContact.datapoints
            name = datapoint.name.toUpperCase()


            switch name
                when 'TEL'
                    addContactField 'phoneNumbers', datapoint

                when 'EMAIL'
                    addContactField 'emails', datapoint
                when 'ADR'
                    cordovaContact.addresses = [] unless cordovaContact.addresses

                    cordovaContact.addresses.push new ContactAddress undefined
                    , datapoint.type
                    # in cozy Contacts, streetAddress field contains everything.
                    , datapoint.value[2], datapoint.value[2]

                when 'CHAT'
                    addContactField 'ims', datapoint

                when 'SOCIAL' or 'URL'
                    addContactField 'urls', datapoint

    cleanBDay = (bday) ->
        try
            d = new Date bday
            return d.valueOf()
        catch error
            return undefined





    c = navigator.contacts.create
        #TODO ? id || rawId :  id
        # vCard FullName = display name
        # (Prefix Given Middle Familly Suffix), or something else.
        displayName: cozyContact.fn
        # vCard Name = splitted
        # (Familly;Given;Middle;Prefix;Suffix)
        name: n2ContactName cozyContact.n
        nickname: cozyContact.nickname
        organizations: cozyContact2ContactOrganizations cozyContact
        birthday: cozyContact.bday # check date format !
        urls: cozyContact2URLs cozyContact
        # TODO extract somes.cozyContact.datapoints    : [DataPoint]
        note: cozyContact.note
        categories: tags2Categories cozyContact.tags #
        photos: attachments2Photos cozyContact

    dataPoints2Cordova cozyContact, c

    return c

Contact.cordova2Cozy = (cordovaContact, callback) ->
    contactName2N = (contactName) ->
        parts = []
        for field in ['familyName', 'givenName', 'middle', 'prefix', 'suffix']
            parts.push contactName[field] or ''

        return parts.join ';'


    categories2Tags = (categories) ->
        if categories?
            return caterories.map (categorie) -> return category.value
        else
            return []

    organisations2Cozy = (organisations, cozyContact) ->
        if organisations?.length > 0
            organisation = organisations[0]
            cozyContact.org = organisation.name
            cozyContact.department = organisation.department
            cozyContact.title = organisation.title

    cordova2Datapoints = (cordovaContact) ->
        datapoints = []
        field2Name =
            'phoneNumbers': 'tel'
            'emails': 'mail'
            'ims': 'chat'
            'urls': 'social'

        for fieldName, name of field2Name
            fields = cordovaContact[fieldName]
            if fields?.length > 0
                fieldsDatapoints = fields.map (contactField) ->
                    name: name
                    type: contactField.type
                    value: contactField.value

                datapoints = datapoints.concat fieldsDatapoints

        if cordovaContact.addresses?.length > 0
            fieldsDatapoints = cordovaContact.addresses.map (contactAddress) ->
                name: 'adr'
                type: contactAddress.type
                value: ['', '', contactAddress.formatted, '', '', '', '']

            datapoints = datapoints.concat fieldsDatapoints

        return datapoints




    c =
        docType: 'contact'
        #TODO ! id            : String
        # vCard FullName = display name
        # (Prefix Given Middle Familly Suffix), or something else.
        fn: cordovaContact.displayName
        # vCard Name = splitted
        # (Familly;Given;Middle;Prefix;Suffix)
        n: contactName2N cordovaContact.name
        bday: cordovaContact.birthday
        nickname: cordovaContact.nickname
        # TODO in datapoints url:
        # TODO ? revision
        # TOTO datapoints
        note: cordovaContact.note
        tags: categories2Tags cordovaContact.categories

    organisations2Cozy cordovaContact.organisations, c

    c.datapoints = cordova2Datapoints cordovaContact


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
                # TODO
                #revpos: _rev.split('-')[0]


        callback null, c

    img.src = photo.value

    # return c

