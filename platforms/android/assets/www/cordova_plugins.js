cordova.define('cordova/plugin_list', function(require, exports, module) {
module.exports = [
    {
        "file": "plugins/com.couchbase.lite.phonegap/www/cblite.js",
        "id": "com.couchbase.lite.phonegap.CouchbaseLite",
        "clobbers": [
            "window.cblite"
        ]
    }
];
module.exports.metadata = 
// TOP OF METADATA
{
    "com.couchbase.lite.phonegap": "0.2.0"
}
// BOTTOM OF METADATA
});