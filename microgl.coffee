glproto = WebGLRenderingContext.prototype

# uniform type suffix
TYPESUFFIX = {}
TYPESUFFIX[glproto.FLOAT]        = '1f'
TYPESUFFIX[glproto.FLOAT_VEC2]   = '2fv'
TYPESUFFIX[glproto.FLOAT_VEC3]   = '3fv'
TYPESUFFIX[glproto.FLOAT_VEC4]   = '4fv'
TYPESUFFIX[glproto.INT]          = '1i'
TYPESUFFIX[glproto.INT_VEC2]     = '2iv'
TYPESUFFIX[glproto.INT_VEC3]     = '3iv'
TYPESUFFIX[glproto.INT_VEC4]     = '4iv'
TYPESUFFIX[glproto.BOOL]         = '1i'
TYPESUFFIX[glproto.BOOL_VEC2]    = '2iv'
TYPESUFFIX[glproto.BOOL_VEC3]    = '3iv'
TYPESUFFIX[glproto.BOOL_VEC4]    = '4iv'
TYPESUFFIX[glproto.FLOAT_MAT2]   = 'Matrix2fv'
TYPESUFFIX[glproto.FLOAT_MAT3]   = 'Matrix3fv'
TYPESUFFIX[glproto.FLOAT_MAT4]   = 'Matrix4fv'
TYPESUFFIX[glproto.SAMPLER_2D]   = 'Sampler2D'
TYPESUFFIX[glproto.SAMPLER_CUBE] = 'SamplerCube'

# attribute type sizes
TYPESIZE = {}
TYPESIZE[glproto.FLOAT]      = 1
TYPESIZE[glproto.FLOAT_VEC2] = 2
TYPESIZE[glproto.FLOAT_VEC3] = 3
TYPESIZE[glproto.FLOAT_VEC4] = 4
TYPESIZE[glproto.INT]        = 1
TYPESIZE[glproto.INT_VEC2]   = 2
TYPESIZE[glproto.INT_VEC3]   = 3
TYPESIZE[glproto.INT_VEC4]   = 4
TYPESIZE[glproto.BOOL]       = 1
TYPESIZE[glproto.BOOL_VEC2]  = 2
TYPESIZE[glproto.BOOL_VEC3]  = 3
TYPESIZE[glproto.BOOL_VEC4]  = 4
TYPESIZE[glproto.FLOAT_MAT2] = 4
TYPESIZE[glproto.FLOAT_MAT3] = 9
TYPESIZE[glproto.FLOAT_MAT4] = 16


class MicroGL
  constructor: (opt) ->
    c = document.createElement('canvas')
    @gl = c.getContext('webgl', opt) or c.getContext('experimental-webgl', opt)
    @enabled = !!@gl
    @uniforms = {}
    @attributes = {}
    @textures = {}
    @cache = {}


  init: (elem, width=256, height=256) ->
    @width = @gl.canvas.width = width
    @height = @gl.canvas.height = height
    elem?.appendChild(@gl.canvas)
    @gl.viewport(0, 0, width, height)
    @gl.clearColor(0, 0, 0, 1)
    @gl.clearDepth(1)
    @gl.enable(@gl.DEPTH_TEST)
    @gl.depthFunc(@gl.LEQUAL)
    @


  makeProgram: (vsSource, fsSource) ->
    initShader = (type, source) =>
      shader = @gl.createShader(type)
      @gl.shaderSource(shader, source)
      @gl.compileShader(shader)
      if not @gl.getShaderParameter(shader, @gl.COMPILE_STATUS)
        console.log(@gl.getShaderInfoLog(shader))
      @gl.attachShader(program, shader)

    program = @gl.createProgram()
    initShader(@gl.VERTEX_SHADER, vsSource)
    initShader(@gl.FRAGMENT_SHADER, fsSource)

    @gl.linkProgram(program)
    if not @gl.getProgramParameter(program, @gl.LINK_STATUS)
      console.log(@gl.getProgramInfoLog(program))
    else
      program


  program: (vsSource, fsSource) ->
    # param: (vsSource, fsSource) or (program)
    program = if fsSource then @makeProgram(vsSource, fsSource) else vsSource
    @uniforms = {}
    @attributes = {}
    @_useElementArray = false

    @gl.useProgram(program)
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_UNIFORMS)]
      uniform = @gl.getActiveUniform(program, i)
      name = uniform.name
      @uniforms[name] = {
        location: @gl.getUniformLocation(program, name)
        type: uniform.type
        size: uniform.size # array length
        name
      }
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_ATTRIBUTES)]
      attribute = @gl.getActiveAttrib(program, i)
      name = attribute.name
      loc = @gl.getAttribLocation(program, name)
      @gl.enableVertexAttribArray(loc)
      @attributes[name] = {
        location: loc
        type: attribute.type
        size: attribute.size
        name
      }
    @


  loadImages: (paths, callback, failCallback) ->
    if typeof paths is 'string'
      paths = [paths]
    left = paths.length
    error = 0
    onload = -> --left or callback(imgs...)
    onerror = -> error++ or failCallback?()
    imgs = (for path in paths
      img = document.createElement 'img'
      img.onload = onload
      img.onerror = onerror
      img.src = path
      img
    )

  texParameter: (tex, param={}, cube) ->
    type = if cube then @gl.TEXTURE_CUBE_MAP else @gl.TEXTURE_2D
    filter = @gl[param.filter ? 'LINEAR']
    wrap = @gl[param.wrap ? 'CLAMP_TO_EDGE']

    @gl.bindTexture(type, tex)
    @gl.texParameteri(type, @gl.TEXTURE_MAG_FILTER, filter)
    @gl.texParameteri(type, @gl.TEXTURE_MIN_FILTER, filter)
    @gl.texParameteri(type, @gl.TEXTURE_WRAP_S, wrap)
    @gl.texParameteri(type, @gl.TEXTURE_WRAP_T, wrap)
    @gl.bindTexture(type, null)
    @

  texParameterCube: (tex, param) ->
    @texParameter(tex, param, true)

  _setTexture: (img, tex, empty) ->
    @gl.bindTexture(@gl.TEXTURE_2D, tex)
    @gl.pixelStorei(@gl.UNPACK_FLIP_Y_WEBGL, true)
    if empty
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA,
        img.width, img.height, 0, @gl.RGBA, @gl.UNSIGNED_BYTE, null)
    else
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, img)
    @gl.bindTexture(@gl.TEXTURE_2D, null)
    @texParameter(tex)

  _setTextureCube: (imgs, tex) ->
    @gl.bindTexture(@gl.TEXTURE_CUBE_MAP, tex)
    # POSITIVE_X 34069
    # NEGATIVE_X 34070
    # POSITIVE_Y 34071
    # NEGATIVE_Y 34072
    # POSITIVE_Z 34073
    # NEGATIVE_Z 34074
    for img, i in imgs
      @gl.texImage2D(
        @gl.TEXTURE_CUBE_MAP_POSITIVE_X + i,
        0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, img
      )
    @gl.bindTexture(@gl.TEXTURE_CUBE_MAP, null)
    @texParameterCube(tex)

  texture: (source, tex, callback) ->
    return source if source instanceof WebGLTexture
    tex or= @gl.createTexture()
    if typeof source is 'string'
      @loadImages source, (img) =>
        @_setTexture(img, tex)
        if callback
          callback(tex)
        else if @_drawArg
          @gl.bindTexture(@gl.TEXTURE_2D, tex)
          @draw(@_drawArg...)
    else
      # <img>, <video>, <canvas>, ImageData object, etc.
      @_setTexture(source, tex)
    tex

  textureCube: (source, tex, callback) ->
    return source if source instanceof WebGLTexture
    tex or= @gl.createTexture()
    # source should be an array-like object
    if typeof source[0] is 'string'
      @loadImages source, (imgs...) =>
        @_setTextureCube(imgs, tex)
        if callback
          callback(tex)
        else if @_drawArg
          @gl.bindTexture(@gl.TEXTURE_CUBE_MAP, tex)
          @draw(@_drawArg...)
    else
      @_setTextureCube(source, tex)
    tex

  variable: (param, useCache) ->
    obj = {}
    for name in Object.keys param
      value = param[name]
      if uniform = @uniforms[name]
        switch TYPESUFFIX[uniform.type]
          when 'Sampler2D'
            if useCache
              value = @cache[name] = @texture(value, @cache[name])
            else
              value = @texture(value)
          when 'SamplerCube'
            if useCache
              value = @cache[name] = @textureCube(value, @cache[name])
            else
              value = @textureCube(value)
        obj[name] = value
      else if @attributes[name] or (name is 'INDEX')
        if not value?
          obj[name] = null
          continue
        if useCache
          # useCache でかつ cache があるときは createBuffer しない
          buffer = @cache[name] or= @gl.createBuffer()
        else
          buffer = @gl.createBuffer()
        if name is 'INDEX'
          @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, buffer)
          @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(value), @gl.STATIC_DRAW)
        else
          @gl.bindBuffer(@gl.ARRAY_BUFFER, buffer)
          @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(value), @gl.STATIC_DRAW)
        buffer.length = value.length
        obj[name] = buffer
    obj


  _bindUniform: (uniform, value) ->
    suffix = TYPESUFFIX[uniform.type]
    if ~suffix.indexOf('Sampler')
      @textures[uniform.name] = value
    else if ~suffix.indexOf('Matrix')
      @gl["uniform" + suffix](uniform.location, false, new Float32Array(value))
    else
      @gl["uniform" + suffix](uniform.location, value)


  _rebindTexture: ->
    texIndex = 0
    for name in Object.keys @uniforms
      uniform = @uniforms[name]
      if uniform.type is @gl.SAMPLER_2D
        type = @gl.TEXTURE_2D
      else if uniform.type is @gl.SAMPLER_CUBE
        type = @gl.TEXTURE_CUBE_MAP
      else continue
      @gl.activeTexture(@gl['TEXTURE' + texIndex])
      @gl.bindTexture(type, @textures[name])
      @gl.uniform1i(uniform.location, texIndex)
      texIndex++
    @


  _bindAttribute: (attribute, value) ->
    size = TYPESIZE[attribute.type]
    @gl.bindBuffer(@gl.ARRAY_BUFFER, value)
    @gl.vertexAttribPointer(attribute.location, size, @gl.FLOAT, false, 0, 0)
    @_numArrays = value.length / size

  bind: (obj) ->
    @_drawArg = undefined

    for name in Object.keys obj
      value = obj[name]
      if name is 'INDEX'
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, value)
        @_useElementArray = value?
        @_numElements = value?.length
      else if uniform = @uniforms[name]
        @_bindUniform(uniform, value)
      else if attribute = @attributes[name]
        @_bindAttribute(attribute, value)
    @


  bindVars: (param) ->
    @bind @variable(param, true)


  frame: (width=@width, height=@height, option) ->
    # option = color:true, depth:true, stencil:true
    fb = @gl.createFramebuffer()
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    tex = @gl.createTexture()
    @_setTexture({ width, height }, tex, true)

    rb = @gl.createRenderbuffer()
    @gl.bindRenderbuffer(@gl.RENDERBUFFER, rb)
    @gl.renderbufferStorage(@gl.RENDERBUFFER, @gl.DEPTH_COMPONENT16, width, height)

    @gl.framebufferTexture2D(@gl.FRAMEBUFFER, @gl.COLOR_ATTACHMENT0,
      @gl.TEXTURE_2D, tex, 0)
    @gl.framebufferRenderbuffer(@gl.FRAMEBUFFER, @gl.DEPTH_ATTACHMENT,
      @gl.RENDERBUFFER, rb)

    @gl.bindRenderbuffer(@gl.RENDERBUFFER, null)
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)

    fb.color = tex
    fb


  draw: (type, num) ->
    @_rebindTexture()
    if @_useElementArray
      num ?= @_numElements
      @gl.drawElements(@gl[type or 'TRIANGLES'], num, @gl.UNSIGNED_SHORT, 0)
    else
      num ?= @_numArrays
      @gl.drawArrays(@gl[type or 'TRIANGLE_STRIP'], 0, num)
    @_drawArg = [type, num]
    @

  drawFrame: (fb, type, num) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @draw(type, num)
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @


  clear: ->
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)
    @

  clearFrame: (fb) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @clear()
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @


  read: ->
    canv = @gl.canvas
    width = canv.width
    height = canv.height
    array = new Uint8Array(width * height * 4)
    @gl.readPixels(0, 0, width, height, @gl.RGBA, @gl.UNSIGNED_BYTE, array)
    array


if window
  window.MicroGL = MicroGL
  r = 'equestAnimationFrame'
  window['r'+ r] or= window['webkitR'+ r] or window['mozR'+ r] or (f) -> setTimeout(f, 1000/60)