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


