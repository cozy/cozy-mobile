log = require('/lib/persistent_log')
    prefix: "contact"
    date: true

# Tools to convert contact from cordova to cozy, and from cozy to cordova.
module.exports = Contact = {}

# Convert a cozy contact object in cordova contact object.
Contact.cozy2Cordova = (cozyContact) ->
    # Helpers

    # Convert 'n' field to cordova ContactName object.
    # @param the cozy's n field.
    n2ContactName = (n) ->
        return undefined unless n?

        parts =  n.split ';'
        [familyName, givenName, middle, prefix, suffix] = parts

        # Cf cozy-vCard.nToFN :
        validParts = parts.filter (part) -> part? and part isnt ''
        formatted = validParts.join ' '

        return new ContactName formatted, familyName, givenName, \
                                middle, prefix, suffix


    # Build cordova's ContactOrganization list from a cozy contact.
    cozyContact2ContactOrganizations = (contact) ->
        if contact.org
            return [
                new ContactOrganization false, null, contact.org
                , contact.department, contact.title
                ]
        else
            return []


    # Initialize a url's ContactFields list with url field of cozy contact.
    cozyContact2URLs = (contact) ->
        if contact.url
            return [
                new ContactField 'urls', contact.url, false
                ]
        else
            return []


    # Build categories list with cozy's tags.
    tags2Categories = (tags) ->
        if tags
            return tags.map (tag) ->
                return new ContactField 'categories', tag, false
        else
            return []


    # Build pohto (list) field from contact's photo.
    attachments2Photos = (contact) ->
        if contact._attachments? and 'picture' of contact._attachments
            photo = new ContactField 'base64', contact._attachments.picture.data

            return [photo]

        return [];


    # loop trought the cozy's datapoints list and fill up the cordovaContact
    # with
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
                    structuredToFlat = (t) ->
                        t = t.filter (part) -> return part? and part isnt ''
                        return t.join ', '
                    street = structuredToFlat datapoint.value[0..2]
                    countryPart = structuredToFlat datapoint.value[3..6]
                    formatted = street
                    formatted += '\n' + countryPart if countryPart isnt ''

                    cordovaContact.addresses.push new ContactAddress undefined
                    , datapoint.type
                    , formatted, street, datapoint.value[3], datapoint.value[4]
                    , datapoint.value[5], datapoint.value[6]

                when 'CHAT'
                    addContactField 'ims', datapoint


                when 'SOCIAL', 'URL'
                    addContactField 'urls', datapoint

                when 'ABOUT'
                    addContactField 'about', datapoint

                when 'RELATION'
                    addContactField 'relations', datapoint

    # Build cordova contact.
    cordovaContact = navigator.contacts.create
        # vCard FullName = display name
        # (Prefix Given Middle Familly Suffix), or something else.
        displayName: cozyContact.fn
        # vCard Name = splitted
        # (Familly;Given;Middle;Prefix;Suffix)
        name: n2ContactName cozyContact.n
        nickname: cozyContact.nickname
        organizations: cozyContact2ContactOrganizations cozyContact
        birthday: cozyContact.bday
        urls: cozyContact2URLs cozyContact
        note: cozyContact.note
        categories: tags2Categories cozyContact.tags #
        photos: attachments2Photos cozyContact

        sourceId: cozyContact._id
        sync2: cozyContact._rev
        # sync3: cozyContact.revision
        dirty: false
        deleted: false

    dataPoints2Cordova cozyContact, cordovaContact

    # Defensive, not named contact are hard to use...
    unless cordovaContact.displayName
        cordovaContact.displayName = "--"

    return cordovaContact

# Convert a cordova contact to cozy contact (asynchronous).
Contact.cordova2Cozy = (cordovaContact, callback) ->

    contactName2N = (contactName) ->
        return undefined unless contactName?
        parts = []
        for field in ['familyName', 'givenName', 'middleName', 'honorificPrefix', 'honorificSuffix']
            parts.push contactName[field] or ''

        n = parts.join ';'
        return n if n isnt ';;;;'


    categories2Tags = (categories) ->
        if categories?
            return caterories.map (categorie) -> return category.value

    # Pick the first organisation in cordova's organizations field, and put it
    # in cozyContact fields.
    organizations2Cozy = (organizations, cozyContact) ->
        if organizations?.length > 0
            organization = organizations[0]
            cozyContact.org = organization.name
            cozyContact.department = organization.department
            cozyContact.title = organization.title

    # Fill datapoints from cordova data.
    cordova2Datapoints = (cordovaContact, cozyContact) ->
        datapoints = []
        field2Name =
            'phoneNumbers': 'tel'
            'emails': 'email'
            'ims': 'chat'
            'about': 'about'
            'relations': 'relation'

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

        if cordovaContact.urls?.length > 0
            # First url is putted has cozy's url field
            cozyContact.url = cordovaContact.urls[0].value

            fieldsDatapoints = cordovaContact.urls.slice(1).map (contactField) ->
                    name: 'url'
                    type: contactField.type
                    value: contactField.value
            datapoints = datapoints.concat fieldsDatapoints


        cozyContact.datapoints = datapoints


    cozyContact =
        docType: 'contact'
        _id: cordovaContact.sourceId
        id: cordovaContact.sourceId
        _rev: cordovaContact.sync2
        # vCard FullName = display name
        # (Prefix Given Middle Familly Suffix), or something else.
        fn: cordovaContact.displayName
        # vCard Name = splitted
        # (Familly;Given;Middle;Prefix;Suffix)
        n: contactName2N cordovaContact.name
        bday: cordovaContact.birthday
        nickname: cordovaContact.nickname
        revision: new Date().toISOString()
        note: cordovaContact.note
        tags: categories2Tags cordovaContact.categories

    organizations2Cozy cordovaContact.organizations, cozyContact

    cordova2Datapoints cordovaContact, cozyContact

    unless cordovaContact.photos?.length > 0
        return callback null, cozyContact


    photo = cordovaContact.photos[0]

    if photo.type is 'base64'
        cozyContact._attachments =
                picture:
                    content_type: 'application/octet-stream'
                    data: photo.value

        callback null, cozyContact

    else if photo.type is 'url'
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

            cozyContact._attachments =
                picture:
                    content_type: 'application/octet-stream'
                    data: dataUrl.split(',')[1]

            callback null, cozyContact

        img.src = photo.value
