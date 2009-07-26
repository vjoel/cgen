class Module
  class InheritError < StandardError; end

  # Called in the context of a class or module, #inherit establishes a secondary
  # inheritance path via #parent. The arguments should be strings or symbols;
  # #parent can refer to an attribute or method with no arguments. The listed
  # methods are given definitions in the base class or module which simply pass
  # the message, along with any arguments and an optional block, to the parent,
  # or throw an InheritError if there is none. For example:
  #
  #    module M
  #      inherit :@parent, :foo
  #    end
  #
  #    class A
  #      def foo
  #        "FOO"
  #      end
  #    end
  #
  #    class B
  #      include M
  #      def initialize
  #        @parent = A.new
  #      end
  #    end
  #
  #    print B.new.foo # ==> "FOO"
  #
  def inherit parent, *methods
    local_var = parent.to_s.sub(/^@?/, "_")
    methods.each do |m|
      module_eval %{
        undef #{m} rescue nil
        def #{m}(*args, &block)
          #{local_var} = #{parent}
          if #{local_var}
            #{local_var}.#{m}(*args, &block)
          else
            raise InheritError, "No #{parent} handles #{m}."
          end
        end
      }
    end
  end
end
