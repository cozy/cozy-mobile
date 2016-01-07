module.exports.config =

    # See docs at https://github.com/brunch/brunch/blob/stable/docs/config.md.

    paths:
        public:  '../www'
        watched: ['app', 'modules', 'vendor']

    plugins:
        coffeelint:
            options:
                indentation: value: 4, level: 'error'

    modules:
        nameCleaner: (path) ->
            path.replace /^(modules|app)\//, ''

    files:
        javascripts:
            joinTo:
                'javascripts/app.js': /^app/
                'javascripts/modules.js': /^modules/
                'javascripts/vendor.js': /^vendor/
            order:
                # Files in `vendor` directories are compiled before other files
                # even if they aren't specified in order.
                before: [
                    'vendor/scripts/jquery.js'
                    'vendor/scripts/underscore.js'
                    'vendor/scripts/backbone.js'
                    'vendor/scripts/moment.js'
                    'vendor/scripts/moment-timezone-with-data.js'
                ]

        stylesheets:
            joinTo: 'stylesheets/app.css'

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'
