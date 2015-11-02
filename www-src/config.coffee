exports.config =

    # See docs at http://brunch.readthedocs.org/en/latest/config.html.

    paths:
        public:  '../www'

    plugins:
        coffeelint:
            options:
                indentation: value: 4, level: 'error'

    conventions:
        vendor:  /(vendor)/ # do not wrap tests in modules

    files:
        javascripts:
            joinTo:
                'javascripts/app.js': /^app/
                'javascripts/vendor.js': /^vendor/
            order:
                # Files in `vendor` directories are compiled before other files
                # even if they aren't specified in order.
                before: [
                    'vendor/scripts/jquery.js'
                    'vendor/scripts/underscore.js'
                    'vendor/scripts/backbone.js'
                    'vendor/scripts/moment.js'
                    'vendor/scripts/moment-timezone.js'
                ]

        stylesheets:
            joinTo: 'stylesheets/app.css'
            order:
                before: []
                after: []

        templates:
            defaultExtension: 'jade'
            joinTo: 'javascripts/app.js'
