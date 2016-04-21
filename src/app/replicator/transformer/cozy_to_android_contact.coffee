log = require('../../lib/persistent_log')
    prefix: "contact"
    date: true


# Helpers


################################################################################
# Convert a cozy contact object in cordova contact object.
#######################################

# Convert 'n' field to cordova ContactName object.
# @param the cozy's n field.
_n2ContactName = (n) ->
    return undefined unless n?

    parts =  n.split ';'
    [familyName, givenName, middle, prefix, suffix] = parts

    # Cf cozy-vCard.nToFN :
    validParts = parts.filter (part) -> part? and part isnt ''
    formatted = validParts.join ' '

    return new ContactName formatted, familyName, givenName, \
        middle, prefix, suffix


# Build cordova's ContactOrganization list from a cozy contact.
_cozyContact2ContactOrganizations = (contact) ->
    if contact.org
        return [
            new ContactOrganization false, null, contact.org
            , contact.department, contact.title
        ]
    else
        return []


# Initialize a url's ContactFields list with url field of cozy contact.
_cozyContact2URLs = (contact) ->
    if contact.url and
        # Avoid duplication of url in datapoints.
        not contact.datapoints.some((dp) ->
            dp.type is "url" and dp.value is contact.url)
        return [
            new ContactField 'other', contact.url, false
        ]
    else
        return []


# Build categories list with cozy's tags.
_tags2Categories = (tags) ->
    if tags
        return tags.map (tag) ->
            return new ContactField 'categories', tag, false
    else
        return []


# Build pohto (list) field from contact's photo.
_attachments2Photos = (contact) ->
    if contact._attachments? and 'picture' of contact._attachments
        photo = new ContactField 'base64', contact._attachments.picture.data

        return [photo]

    return []

_adr2ContactAddress = (datapoint) ->
    if datapoint.value instanceof Array
        structuredToFlat = (t) ->
            t = t.filter (part) -> return part? and part isnt ''
            return t.join ', '
        street = structuredToFlat datapoint.value[0..2]
        countryPart = structuredToFlat datapoint.value[3..6]
        formatted = street
        formatted += '\n' + countryPart if countryPart isnt ''

        return new ContactAddress undefined
        , datapoint.type
        , formatted, street, datapoint.value[3], datapoint.value[4]
        , datapoint.value[5], datapoint.value[6]

    else if typeof(datapoint.value) is 'string'
        return new ContactAddress undefined
        , datapoint.type, datapoint.value, datapoint.value

    else
        log.warning 'adr datapoint has bad type'
        return new ContactAddress undefined, datapoint.type, ''


# loop trought the cozy's datapoints list and fill up the cordovaContact
# with
_dataPoints2Cordova = (cozyContact, cordovaContact) ->
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
                unless cordovaContact.addresses
                    cordovaContact.addresses = []
                cordovaContact.addresses.push @_adr2ContactAddress datapoint

            when 'CHAT'
                addContactField 'ims', datapoint


            when 'SOCIAL', 'URL'
                addContactField 'urls', datapoint

            when 'ABOUT'
                addContactField 'about', datapoint

            when 'RELATION'
                addContactField 'relations', datapoint




################################################################################
# Convert a cordova contact to cozy contact (asynchronous).
#######################################



_contactName2N = (contactName) ->
    return undefined unless contactName?

    parts = []
    fields = [ 'familyName', 'givenName', 'middleName', 'honorificPrefix',
        'honorificSuffix' ]

    for field in fields
        parts.push contactName[field] or ''

    n = parts.join ';'
    return n if n isnt ';;;;'


_categories2Tags = (categories) ->
    if categories?
        return categories.map (category) -> return category.value

# Pick the first organisation in cordova's organizations field, and put it
# in cozyContact fields.
_organizations2Cozy = (organizations, cozyContact) ->
    if organizations?.length > 0
        organization = organizations[0]
        cozyContact.org = organization.name
        cozyContact.department = organization.department
        cozyContact.title = organization.title

# Fill datapoints from cordova data.
_cordova2Datapoints = (cordovaContact, cozyContact) ->
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
        fieldsDatapoints = cordovaContact.urls.map (contactField) ->
            name: 'url'
            type: contactField.type
            value: contactField.value

        datapoints = datapoints.concat fieldsDatapoints


    cozyContact.datapoints = datapoints


module.exports = class CozyToAndroidContact


    transform: (cozyContact) ->
        # Build cordova contact.
        cordovaContact =
            # vCard FullName = display name
            # (Prefix Given Middle Familly Suffix), or something else.
            displayName: cozyContact.fn
            # vCard Name = splitted
            # (Familly;Given;Middle;Prefix;Suffix)
            name: _n2ContactName cozyContact.n
            nickname: cozyContact.nickname
            organizations: _cozyContact2ContactOrganizations cozyContact
            birthday: cozyContact.bday
            urls: _cozyContact2URLs cozyContact
            note: cozyContact.note
            categories: _tags2Categories cozyContact.tags #
            photos: _attachments2Photos cozyContact

            sourceId: cozyContact._id
            sync2: cozyContact._rev
            # sync3: cozyContact.revision
            dirty: false
            deleted: false

        _dataPoints2Cordova cozyContact, cordovaContact

        # Defensive, unnamed contact are hard to use...
        unless cordovaContact.displayName
            cordovaContact.displayName = "--"

        return cordovaContact


    # Convert a cordova contact to cozy contact (asynchronous).
    reverseTransform: (cordovaContact, callback) ->
        return callback new Error 'No cordova contact' unless cordovaContact?
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
            n: _contactName2N cordovaContact.name
            bday: cordovaContact.birthday
            nickname: cordovaContact.nickname
            revision: new Date().toISOString()
            note: cordovaContact.note
            tags: _categories2Tags cordovaContact.categories

        _organizations2Cozy cordovaContact.organizations, cozyContact

        _cordova2Datapoints cordovaContact, cozyContact

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

            img.onerror = -> callback new Error 'While resizing avatar.'

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
