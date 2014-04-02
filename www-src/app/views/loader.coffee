module.exports = (content) ->
    $('body').append el = $ """
            <div class="loading-backdrop" class="enabled">
                <div class="loading">#{content}</div>
            </div>
        """
    view = new ionic.views.Loading el: el[0]
    view.$el = el
    view.show()
    view.setContent = (text) -> $el.find('.loading').text text
    return view
