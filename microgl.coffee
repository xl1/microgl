RC = WebGLRenderingContext

# uniform type suffix
TYPESUFFIX = {}
TYPESUFFIX[RC.FLOAT]        = '1f'
TYPESUFFIX[RC.FLOAT_VEC2]   = '2fv'
TYPESUFFIX[RC.FLOAT_VEC3]   = '3fv'
TYPESUFFIX[RC.FLOAT_VEC4]   = '4fv'
TYPESUFFIX[RC.INT]          = '1i'
TYPESUFFIX[RC.INT_VEC2]     = '2iv'
TYPESUFFIX[RC.INT_VEC3]     = '3iv'
TYPESUFFIX[RC.INT_VEC4]     = '4iv'
TYPESUFFIX[RC.BOOL]         = '1i'
TYPESUFFIX[RC.BOOL_VEC2]    = '2iv'
TYPESUFFIX[RC.BOOL_VEC3]    = '3iv'
TYPESUFFIX[RC.BOOL_VEC4]    = '4iv'
TYPESUFFIX[RC.FLOAT_MAT2]   = 'Matrix2fv'
TYPESUFFIX[RC.FLOAT_MAT3]   = 'Matrix3fv'
TYPESUFFIX[RC.FLOAT_MAT4]   = 'Matrix4fv'
TYPESUFFIX[RC.SAMPLER_2D]   = 'Sampler2D'
TYPESUFFIX[RC.SAMPLER_CUBE] = 'SamplerCube'

# attribute type sizes
TYPESIZE = {}
TYPESIZE[RC.FLOAT]      = 1
TYPESIZE[RC.FLOAT_VEC2] = 2
TYPESIZE[RC.FLOAT_VEC3] = 3
TYPESIZE[RC.FLOAT_VEC4] = 4
TYPESIZE[RC.FLOAT_MAT2] = 4
TYPESIZE[RC.FLOAT_MAT3] = 9
TYPESIZE[RC.FLOAT_MAT4] = 16


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


  _initShader: (type, source) ->
    shader = @gl.createShader(type)
    @gl.shaderSource(shader, source)
    @gl.compileShader(shader)
    if not @gl.getShaderParameter(shader, @gl.COMPILE_STATUS)
      console.log(@gl.getShaderInfoLog(shader))
    else
      shader

  makeProgram: (vsSource, fsSource) ->
    program = @gl.createProgram()
    @gl.attachShader(program, @_initShader(@gl.VERTEX_SHADER, vsSource))
    @gl.attachShader(program, @_initShader(@gl.FRAGMENT_SHADER, fsSource))

    @gl.linkProgram(program)
    if not @gl.getProgramParameter(program, @gl.LINK_STATUS)
      console.log(@gl.getProgramInfoLog(program))
    else
      program


  program: (vsSource, fsSource) ->
    # param: (vsSource, fsSource) or (program)
    program = if fsSource then @makeProgram(vsSource, fsSource) else vsSource
    @uniforms = {}
    for name in Object.keys @attributes
      @gl.disableVertexAttribArray(@attributes[name].location)
    @attributes = {}
    @_useElementArray = false

    @gl.useProgram(program)
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_UNIFORMS)] by 1
      uniform = @gl.getActiveUniform(program, i)
      name = uniform.name
      @uniforms[name] = {
        location: @gl.getUniformLocation(program, name)
        type: uniform.type
        size: uniform.size # array length
        name
      }
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_ATTRIBUTES)] by 1
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


  blend: (sourceFactor, destFactor) ->
    sFactor = ('' + sourceFactor).toUpperCase()
    dFactor = ('' + destFactor).toUpperCase()
    if destFactor
      @gl.enable(@gl.BLEND)
      @gl.blendFunc(@gl[sFactor], @gl[dFactor])
    else switch sFactor
      when 'FALSE'  then @gl.disable(@gl.BLEND)
      when 'TRUE'   then @gl.enable(@gl.BLEND)
      # compositing
      when 'CLEAR'            then @blend('ZERO', 'ZERO')
      when 'COPY'             then @blend('ONE', 'ZERO')
      when 'DESTINATION'      then @blend('ZERO', 'ONE')
      when 'SOURCE-OVER'      then @blend('ONE', 'ONE_MINUS_SRC_ALPHA')
      when 'DESTINATION-OVER' then @blend('ONE_MINUS_DST_ALPHA', 'ONE')
      when 'SOURCE-IN'        then @blend('DST_ALPHA', 'ZERO')
      when 'DESTINATION-IN'   then @blend('ZERO', 'SRC_ALPHA')
      when 'SOURCE-OUT'       then @blend('ONE_MINUS_DST_ALPHA', 'ZERO')
      when 'DESTINATION-OUT'  then @blend('ZERO', 'ONE_MINUS_SRC_ALPHA')
      when 'SOURCE-ATOP'      then @blend('DST_ALPHA', 'ONE_MINUS_SRC_ALPHA')
      when 'DESTINATION-ATOP' then @blend('ONE_MINUS_DST_ALPHA', 'SRC_ALPHA')
      when 'XOR'
        @blend('ONE_MINUS_DST_ALPHA', 'ONE_MINUS_SRC_ALPHA')
      when 'LIGHTER'  then @blend('ONE', 'ONE')
      # blend
      when 'MULTIPLY' then @blend('ZERO', 'SRC_COLOR')
      when 'SCREEN'   then @blend('ONE_MINUS_DST_COLOR', 'ONE')
      when 'EXCLUSION'
        @blend('ONE_MINUS_DST_COLOR', 'ONE_MINUS_SRC_COLOR')
      # other
      when 'ADD'      then @blend('SRC_ALPHA', 'ONE')
      when 'DEFAULT'  then @blend('SRC_ALPHA', 'ONE_MINUS_SRC_ALPHA')
      else console.warn 'unsupported blend mode: ' + sourceFactor
    return


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

  _setTextureCube: (imgs, tex, empty) ->
    @gl.bindTexture(@gl.TEXTURE_CUBE_MAP, tex)
    # POSITIVE_X 34069
    # NEGATIVE_X 34070
    # POSITIVE_Y 34071
    # NEGATIVE_Y 34072
    # POSITIVE_Z 34073
    # NEGATIVE_Z 34074
    if empty
      for i in [0...6]
        @gl.texImage2D(
          @gl.TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, @gl.RGBA,
          imgs.width, imgs.height, 0, @gl.RGBA, @gl.UNSIGNED_BYTE, null
        )
    else
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


  frame: (width=@width, height=@height, flags={}) ->
    # flags =
    #   color: true
    #   depth: true
    #   stencil: false
    #   cube: false
    fb = @gl.createFramebuffer()
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    tex = @gl.createTexture()
    if flags.cube
      @_setTextureCube({ width, height }, tex, true)
    else
      @_setTexture({ width, height }, tex, true)
      @gl.framebufferTexture2D(
        @gl.FRAMEBUFFER, @gl.COLOR_ATTACHMENT0, @gl.TEXTURE_2D, tex, 0)

    rb = @gl.createRenderbuffer()
    @gl.bindRenderbuffer(@gl.RENDERBUFFER, rb)
    @gl.renderbufferStorage(
      @gl.RENDERBUFFER, @gl.DEPTH_COMPONENT16, width, height)
    @gl.framebufferRenderbuffer(
      @gl.FRAMEBUFFER, @gl.DEPTH_ATTACHMENT, @gl.RENDERBUFFER, rb)

    @gl.bindRenderbuffer(@gl.RENDERBUFFER, null)
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)

    fb.color = tex
    fb

  frameCube: (size=@width, flags={}) ->
    flags.cube = true
    @frame(size, size, flags)


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

  drawFrameCube: (fb, idx, type, num) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @gl.framebufferTexture2D(@gl.FRAMEBUFFER, @gl.COLOR_ATTACHMENT0,
      @gl.TEXTURE_CUBE_MAP_POSITIVE_X + idx, fb.color, 0)
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

  clearFrameCube: (fb, idx) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @gl.framebufferTexture2D(@gl.FRAMEBUFFER, @gl.COLOR_ATTACHMENT0,
      @gl.TEXTURE_CUBE_MAP_POSITIVE_X + idx, fb.color, 0)
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