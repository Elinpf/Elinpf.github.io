---
title: Ruby module 模块
date: 2021-10-09 11:09:59
tags:
- ruby
categories:
- 编程
- ruby
---

Ruby 中的模块提供了一个独立的命名空间，可以放置方法和常量，甚至是变量。

## 实例方法和常量的使用

```rb
module MyModule
  def my_method
    puts 'Hello'
  end
  MY_CONSTANT = 'constant'
end

# 通过模块获取常量
puts MyModule::MY_CONSTANT # => 'constant'

class Foo
  include MyModule
end

# 通过实例使用方法
Foo.new.my_method # => "Hello"

# 通过类获取常量
puts Foo::MY_CONSTANT # => 'constant'
```

## 使用模块的变量和模块方法

```rb
module MyModule
  class << self
    attr_accessor :module_var

    def module_method
      puts "module_method"
    end
  end

  self.module_var = "module_var"
end

puts MyModule.module_var  # => "module_var"
MyModule.module_method  # => "module_method"
```

## 建立层级关系

类似于python的import层级，ruby可以用module来建立层级关系，在module中再`require`其他的module.

这里就有个设计技巧，将`core`中`require`所有下一个层级，这样include的时候就不用再`require`了。

例如：

```rb core.rb
# All in this require 

module Aio

# debugger
  #require 'byebug'

# License
    require "aio/license"

# UI
    require "aio/ui"

# Base
    require "aio/base"

# Text
    require "aio/core/text"

# Module
    require "aio/core/module"
    require "aio/core/module_manager"
    require "aio/core/module_loader"

# Warning
    require "aio/core/warning"

# Device
    require "aio/core/device"
    require "aio/core/device_manager"
```

其他文件只需要`require 'core'`就可以了

```rb other_file.rb
require 'core'

include Aio::UI
```

