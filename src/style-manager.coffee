{Emitter, Disposable} = require 'event-kit'

module.exports =

# Extended: The `StyleManager` is a singleton object available via
# `atom.styles`, and keeps track of all style sheets that are loaded via
# packages and themes.
class StyleManager
  constructor: ->
    @emitter = new Emitter
    @styleElements = []
    @styleElementsBySourcePath = {}

  ###
  Section: Event Subscription
  ###

  # Extended: Invoke `callback` for all current and future style elements.
  #
  # * `callback` {Function} that is called with style elements.
  #   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  #     will be null because this element isn't attached to the DOM. If you want
  #     to attach this element to the DOM, be sure to clone it first by calling
  #     `.cloneNode(true)` on it. The style element will also have the following
  #     non-standard properties:
  #     * `sourcePath` A {String} containing the path from which the style
  #       element was loaded.
  #     * `context` A {String} indicating the target context of the style
  #       element.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to cancel the
  # subscription.
  observeStyleElements: (callback) ->
    callback(styleElement) for styleElement in @getStyleElements()
    @onDidAddStyleElement(callback)

  # Extended: Invoke `callback` when a style element is added.
  #
  # * `callback` {Function} that is called with style elements.
  #   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  #     will be null because this element isn't attached to the DOM. If you want
  #     to attach this element to the DOM, be sure to clone it first by calling
  #     `.cloneNode(true)` on it. The style element will also have the following
  #     non-standard properties:
  #     * `sourcePath` A {String} containing the path from which the style
  #       element was loaded.
  #     * `context` A {String} indicating the target context of the style
  #       element.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to cancel the
  # subscription.
  onDidAddStyleElement: (callback) ->
    @emitter.on 'did-add-style-element', callback

  # Extended: Invoke `callback` when a style element is removed.
  #
  # * `callback` {Function} that is called with style elements.
  #   * `styleElement` An `HTMLStyleElement` instance.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to cancel the
  # subscription.
  onDidRemoveStyleElement: (callback) ->
    @emitter.on 'did-remove-style-element', callback

  # Extended: Invoke `callback` when an existing style element is updated.
  #
  # * `callback` {Function} that is called with style elements.
  #   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  #      will be null because this element isn't attached to the DOM. The style
  #      element will also have the following non-standard properties:
  #     * `sourcePath` A {String} containing the path from which the style
  #       element was loaded.
  #     * `context` A {String} indicating the target context of the style
  #       element.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to cancel the
  # subscription.
  onDidUpdateStyleElement: (callback) ->
    @emitter.on 'did-update-style-element', callback

  ###
  Section: Reading Style Elements
  ###

  # Extended: Get all loaded style elements.
  getStyleElements: ->
    @styleElements.slice()

  addStyleSheet: (source, params) ->
    sourcePath = params?.sourcePath
    context = params?.context
    group = params?.group

    if sourcePath? and styleElement = @styleElementsBySourcePath[sourcePath]
      updated = true
    else
      styleElement = document.createElement('style')
      if sourcePath?
        styleElement.sourcePath = sourcePath
        styleElement.setAttribute('source-path', sourcePath)

      if context?
        styleElement.context = context
        styleElement.setAttribute('context', context)

      if group?
        styleElement.group = group
        styleElement.setAttribute('group', group)

    styleElement.textContent = source

    if updated
      @emitter.emit 'did-update-style-element', styleElement
    else
      @addStyleElement(styleElement)

    new Disposable => @removeStyleElement(styleElement)

  addStyleElement: (styleElement) ->
    {sourcePath, group} = styleElement

    if group?
      for existingElement, index in @styleElements
        if existingElement.group is group
          insertIndex = index + 1
        else
          break if insertIndex?
    insertIndex ?= @styleElements.length

    @styleElements.splice(insertIndex, 0, styleElement)
    @styleElementsBySourcePath[sourcePath] ?= styleElement if sourcePath?
    @emitter.emit 'did-add-style-element', styleElement

  removeStyleElement: (styleElement) ->
    index = @styleElements.indexOf(styleElement)
    unless index is -1
      @styleElements.splice(index, 1)
      delete @styleElementsBySourcePath[styleElement.sourcePath] if styleElement.sourcePath?
      @emitter.emit 'did-remove-style-element', styleElement

  getSnapshot: ->
    @styleElements.slice()

  restoreSnapshot: (styleElementsToRestore) ->
    for styleElement in @getStyleElements()
      @removeStyleElement(styleElement) unless styleElement in styleElementsToRestore

    existingStyleElements = @getStyleElements()
    for styleElement in styleElementsToRestore
      @addStyleElement(styleElement) unless styleElement in existingStyleElements
