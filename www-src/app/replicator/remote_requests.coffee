all = (doc) -> emit doc._id, doc._id

module.exports =
    file:
        all: all

    folder:
        all: all

    contact:
        all: all

    event:
        all: all

    tag:
        byname: (doc) -> emit doc.name, doc._id

    notification:
        all: all
