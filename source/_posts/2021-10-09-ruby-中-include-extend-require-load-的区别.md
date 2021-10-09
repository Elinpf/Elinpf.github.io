---
title: ruby 中 include extend require load 的区别
date: 2021-10-09 11:29:01
tags:
- ruby
categories:
- 编程
- ruby
---

## include

include 相当于将模块定义的方法和常量插入到类中，mixin的能力可以实现多继承。

```rb
module Log 
  def class_type
    "This class is of type: #{self.class}"
  end
end

class TestClass 
  include Log 
end

tc = TestClass.new.class_type
puts tc #This class is of type: TestClass
```

## extend

extend 用于添加类方法而不是include的实例方法。

```rb
module Log
  def class_type
    "This class is of type: #{self.class}"
  end
end

class TestClass
  extend Log
  # ...
end

tc = TestClass.class_type
puts tc  # This class is of type: TestClass
```

## require

用于加载库，并阻止多次加载。

```rb test_libary.rb
puts " load this libary "
```

```rb test_require.rb
puts (require './test_library')
puts (require './test_library')
puts (require './test_library')
# 结果为
#  load this libary 
# true
# false
# false
```

## load

同样用于加载库，但是不会阻止多次加载。用于模块的状态经常发生变化的情况

```rb
puts load "./test_library.rb"  #在这里不能省略 .rb, require可以省略
puts load "./test_library.rb" 
puts load "./test_library.rb" 
#结果
# load this libary
#true
# load this libary
#true
# load this libary
#true
```

## require_relative

相对位置的引用

```rb
require_relative('path')

# equal to

require(File.expand_path('path', File.dirname(__FILE__)))
```

