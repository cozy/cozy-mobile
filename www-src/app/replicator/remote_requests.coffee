all = (doc) -> emit doc._id, doc._id

module.exports =
    file:
        all: all

    folder:
        all: all
        byFullPath: (doc) -> emit (doc.path + '/' + doc.name), doc._id

    contact:
        all: all

    event:
        all: all

    tag:
        byname: (doc) -> emit doc.name, doc._id

    notification:
        all: all

    cozyinstance:
        all: all
