// Generated by CoffeeScript 1.4.0
(function() {
  var MicroGL, TYPESIZE, TYPESUFFIX, glproto, r, _name;

  glproto = WebGLRenderingContext.prototype;

  TYPESUFFIX = {};

  TYPESUFFIX[glproto.FLOAT] = '1f';

  TYPESUFFIX[glproto.FLOAT_VEC2] = '2fv';

  TYPESUFFIX[glproto.FLOAT_VEC3] = '3fv';

  TYPESUFFIX[glproto.FLOAT_VEC4] = '4fv';

  TYPESUFFIX[glproto.INT] = '1i';

  TYPESUFFIX[glproto.INT_VEC2] = '2iv';

  TYPESUFFIX[glproto.INT_VEC3] = '3iv';

  TYPESUFFIX[glproto.INT_VEC4] = '4iv';

  TYPESUFFIX[glproto.FLOAT_MAT2] = 'Matrix2fv';

  TYPESUFFIX[glproto.FLOAT_MAT3] = 'Matrix3fv';

  TYPESUFFIX[glproto.FLOAT_MAT4] = 'Matrix4fv';

  TYPESUFFIX[glproto.SAMPLER_2D] = 'Sampler2D';

  TYPESUFFIX[glproto.SAMPLER_CUBE] = 'SamplerCube';

  TYPESIZE = {};

  TYPESIZE[glproto.FLOAT] = 1;

  TYPESIZE[glproto.FLOAT_VEC2] = 2;

  TYPESIZE[glproto.FLOAT_VEC3] = 3;

  TYPESIZE[glproto.FLOAT_VEC4] = 4;

  TYPESIZE[glproto.FLOAT_MAT2] = 4;

  TYPESIZE[glproto.FLOAT_MAT3] = 9;

  TYPESIZE[glproto.FLOAT_MAT4] = 16;

  MicroGL = (function() {

    function MicroGL(opt) {
      var c;
      c = document.createElement('canvas');
      this.gl = c.getContext('webgl', opt) || c.getContext('experimental-webgl', opt);
      this.enabled = !!this.gl;
      this.uniforms = {};
      this.attributes = {};
      this.textures = {};
    }

    MicroGL.prototype.init = function(elem, width, height) {
      if (width == null) {
        width = 256;
      }
      if (height == null) {
        height = 256;
      }
      this.width = this.gl.canvas.width = width;
      this.height = this.gl.canvas.height = height;
      if (elem != null) {
        elem.appendChild(this.gl.canvas);
      }
      this.gl.viewport(0, 0, width, height);
      this.gl.clearColor(0, 0, 0, 1);
      this.gl.clearDepth(1);
      this.gl.enable(this.gl.DEPTH_TEST);
      this.gl.depthFunc(this.gl.LEQUAL);
      return this;
    };

    MicroGL.prototype.makeProgram = function(vsSource, fsSource) {
      var initShader, program,
        _this = this;
      initShader = function(type, source) {
        var shader;
        shader = _this.gl.createShader(type);
        _this.gl.shaderSource(shader, source);
        _this.gl.compileShader(shader);
        if (!_this.gl.getShaderParameter(shader, _this.gl.COMPILE_STATUS)) {
          console.log(_this.gl.getShaderInfoLog(shader));
        }
        return _this.gl.attachShader(program, shader);
      };
      program = this.gl.createProgram();
      initShader(this.gl.VERTEX_SHADER, vsSource);
      initShader(this.gl.FRAGMENT_SHADER, fsSource);
      this.gl.linkProgram(program);
      if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
        return console.log(this.gl.getProgramInfoLog(program));
      } else {
        return program;
      }
    };

    MicroGL.prototype.program = function(vsSource, fsSource) {
      var attribute, i, loc, program, uniform, _i, _j, _ref, _ref1;
      program = fsSource ? this.makeProgram(vsSource, fsSource) : vsSource;
      this.uniforms = {};
      this.attributes = {};
      this._useElementArray = false;
      this._texnum = 0;
      this.gl.useProgram(program);
      for (i = _i = 0, _ref = this.gl.getProgramParameter(program, this.gl.ACTIVE_UNIFORMS); 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        uniform = this.gl.getActiveUniform(program, i);
        this.uniforms[uniform.name] = {
          location: this.gl.getUniformLocation(program, uniform.name),
          type: uniform.type,
          size: uniform.size
        };
      }
      for (i = _j = 0, _ref1 = this.gl.getProgramParameter(program, this.gl.ACTIVE_ATTRIBUTES); 0 <= _ref1 ? _j < _ref1 : _j > _ref1; i = 0 <= _ref1 ? ++_j : --_j) {
        attribute = this.gl.getActiveAttrib(program, i);
        loc = this.gl.getAttribLocation(program, attribute.name);
        this.gl.enableVertexAttribArray(loc);
        this.attributes[attribute.name] = {
          location: loc,
          type: attribute.type,
          size: attribute.size
        };
      }
      return this;
    };

    MicroGL.prototype._setTexture = function(img, tex, empty) {
      this.gl.bindTexture(this.gl.TEXTURE_2D, tex);
      this.gl.pixelStorei(this.gl.UNPACK_FLIP_Y_WEBGL, true);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.LINEAR);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.LINEAR);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);
      if (empty) {
        return this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, img.width, img.height, 0, this.gl.RGBA, this.gl.UNSIGNED_BYTE, null);
      } else {
        return this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, this.gl.RGBA, this.gl.UNSIGNED_BYTE, img);
      }
    };

    MicroGL.prototype.texture = function(source, tex, callback) {
      var img,
        _this = this;
      if (source instanceof WebGLTexture) {
        return source;
      }
      if (tex == null) {
        tex = this.gl.createTexture();
      }
      if (typeof source === 'string') {
        img = document.createElement('img');
        img.onload = function() {
          _this._setTexture(img, tex);
          if (callback) {
            return callback(tex);
          } else if (_this._drawArg) {
            _this.gl.bindTexture(_this.gl.TEXTURE_2D, tex);
            return _this.draw.apply(_this, _this._drawArg);
          }
        };
        img.src = source;
      } else {
        this._setTexture(source, tex);
      }
      return tex;
    };

    MicroGL.prototype.variable = function(param, cacheTexture) {
      var attribute, buffer, name, obj, uniform, value, _i, _len, _ref;
      obj = {};
      _ref = Object.keys(param);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        value = param[name];
        if (uniform = this.uniforms[name]) {
          if (~TYPESUFFIX[uniform.type].indexOf('Sampler')) {
            if (cacheTexture) {
              value = this.textures[name] = this.texture(value, this.textures[name]);
            } else {
              value = this.texture(value);
            }
          }
          obj[name] = value;
        } else if (attribute = this.attributes[name]) {
          buffer = this.gl.createBuffer();
          this.gl.bindBuffer(this.gl.ARRAY_BUFFER, buffer);
          this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(value), this.gl.STATIC_DRAW);
          buffer.length = value.length;
          obj[name] = buffer;
        } else if (name === 'INDEX') {
          if (value) {
            buffer = this.gl.createBuffer();
            this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, buffer);
            this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(value), this.gl.STATIC_DRAW);
            buffer.length = value.length;
            obj[name] = buffer;
          } else {
            obj[name] = null;
          }
        }
      }
      return obj;
    };

    MicroGL.prototype._bindUniform = function(uniform, value) {
      var suffix, type;
      suffix = TYPESUFFIX[uniform.type];
      if (~suffix.indexOf('Sampler')) {
        type = suffix === 'Sampler2D' ? this.gl.TEXTURE_2D : this.gl.TEXTURE_CUBE_MAP;
        this.gl.activeTexture(this.gl['TEXTURE' + this._texnum]);
        this.gl.bindTexture(type, value);
        this.gl.uniform1i(uniform.location, this._texnum);
        return this._texnum++;
      } else if (~suffix.indexOf('Matrix')) {
        return this.gl["uniform" + suffix](uniform.location, false, new Float32Array(value));
      } else {
        return this.gl["uniform" + suffix](uniform.location, value);
      }
    };

    MicroGL.prototype._bindAttribute = function(attribute, value) {
      var size;
      size = TYPESIZE[attribute.type];
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, value);
      this.gl.vertexAttribPointer(attribute.location, size, this.gl.FLOAT, false, 0, 0);
      return this._numArrays = value.length / size;
    };

    MicroGL.prototype.bind = function(obj) {
      var attribute, name, uniform, value, _i, _len, _ref;
      this._drawArg = void 0;
      _ref = Object.keys(obj);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        value = obj[name];
        if (name === 'INDEX') {
          this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, value);
          this._useElementArray = value != null;
          this._numElements = value != null ? value.length : void 0;
        } else if (uniform = this.uniforms[name]) {
          this._bindUniform(uniform, value);
        } else if (attribute = this.attributes[name]) {
          this._bindAttribute(attribute, value);
        }
      }
      return this;
    };

    MicroGL.prototype.bindVars = function(param) {
      return this.bind(this.variable(param, true));
    };

    MicroGL.prototype.frame = function(width, height, option) {
      var fb, rb, tex;
      if (width == null) {
        width = this.width;
      }
      if (height == null) {
        height = this.height;
      }
      fb = this.gl.createFramebuffer();
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, fb);
      tex = this.gl.createTexture();
      this._setTexture({
        width: width,
        height: height
      }, tex, true);
      rb = this.gl.createRenderbuffer();
      this.gl.bindRenderbuffer(this.gl.RENDERBUFFER, rb);
      this.gl.renderbufferStorage(this.gl.RENDERBUFFER, this.gl.DEPTH_COMPONENT16, width, height);
      this.gl.framebufferTexture2D(this.gl.FRAMEBUFFER, this.gl.COLOR_ATTACHMENT0, this.gl.TEXTURE_2D, tex, 0);
      this.gl.framebufferRenderbuffer(this.gl.FRAMEBUFFER, this.gl.DEPTH_ATTACHMENT, this.gl.RENDERBUFFER, rb);
      this.gl.bindRenderbuffer(this.gl.RENDERBUFFER, null);
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, null);
      fb.color = tex;
      return fb;
    };

    MicroGL.prototype.draw = function(type, num) {
      if (this._useElementArray) {
        if (num == null) {
          num = this._numElements;
        }
        this.gl.drawElements(this.gl[type || 'TRIANGLES'], num, this.gl.UNSIGNED_SHORT, 0);
      } else {
        if (num == null) {
          num = this._numArrays;
        }
        this.gl.drawArrays(this.gl[type || 'TRIANGLE_STRIP'], 0, num);
      }
      this._drawArg = [type, num];
      this._texnum = 0;
      return this;
    };

    MicroGL.prototype.drawFrame = function(fb, type, num) {
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, fb);
      this.draw(type, num);
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, null);
      return this;
    };

    MicroGL.prototype.clear = function() {
      this.gl.clear(this.gl.COLOR_BUFFER_BIT | this.gl.DEPTH_BUFFER_BIT);
      return this;
    };

    MicroGL.prototype.clearFrame = function(fb) {
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, fb);
      this.clear();
      this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, null);
      return this;
    };

    MicroGL.prototype.read = function() {
      var array, canv, height, width;
      canv = this.gl.canvas;
      width = canv.width;
      height = canv.height;
      array = new Uint8Array(width * height * 4);
      this.gl.readPixels(0, 0, width, height, this.gl.RGBA, this.gl.UNSIGNED_BYTE, array);
      return array;
    };

    return MicroGL;

  })();

  if (window) {
    window.MicroGL = MicroGL;
    r = 'equestAnimationFrame';
    window[_name = 'r' + r] || (window[_name] = window['webkitR' + r] || window['mozR' + r] || function(f) {
      return setTimeout(f, 1000 / 60);
    });
  }

}).call(this);
