path = require 'path'


module.exports.uniqueId = (length = 8) ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < length
    id.substr 0, length

module.exports.deepExtend = deepExtend = (object, extenders...) ->
    return {} if not object?
    for other in extenders
        for own key, val of other
            object[key] = if not object[key]? or typeof val isnt "object" then val else deepExtend object[key], val
    object

module.exports.getParentFolderName = getParentFolderName = (pathname, exclude = []) ->
    basename = path.basename pathname
    return unless basename not in exclude then getParentFolderName path.dirname pathname else basename
