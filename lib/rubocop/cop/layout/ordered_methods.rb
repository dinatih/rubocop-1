# frozen_string_literal: true

# TODO: when finished, run `rake generate_cops_documentation` to update the docs
module RuboCop
  module Cop
    module Layout
      # TODO: Write cop description and example of bad / good code. For every
      # `SupportedStyle` and unique configuration, there needs to be examples.
      # Examples must have valid Ruby syntax. Do not use upticks.
      #
      # @example EnforcedStyle: bar (default)
      #   # Description of the `bar` style.
      #
      #   # bad
      #   def b_method; end
      #
      #   def a_method; end
      #
      #   def initialize; end
      #
      #   # good
      #   def initialize; end
      #
      #   def a_method; end
      #
      #   def b_method; end
      #
      class OrderedMethods < Cop
        include RangeHelp

        MSG = 'Method should be sorted in an alphabetical order ' \
              'within their section of class/module visibility. Method ' \
              '`%<current>s` should appear before `%<previous>s`.'

        def initialize(config = nil, options = nil)
          super

          @method_definitions = {}
        end

        def_node_search :instance_method_definitions, <<-PATTERN
          (def ...)
        PATTERN

        def_node_search :class_method_definitions, <<-PATTERN
          (defs ...)
        PATTERN

        def_node_matcher :visibility_block?, <<-PATTERN
          (send nil? { :private :protected :public })
        PATTERN

        def autocorrect(node)
          node_visibility = node_visibility(node)
          current_visibility_methods = @method_definitions[node_visibility]

          current_index = current_visibility_methods.find_index(node)
          previous_index = current_index - 1
          previous = current_visibility_methods[previous_index]

          current_range = method_definition_with_comment(node)
          previous_range = method_definition_with_comment(previous)

          lambda do |corrector|
            corrector.insert_before(previous_range, current_range.source)
            corrector.remove(current_range)
          end
        end

        def on_class(class_node)
          @method_definitions[:initializer] =
            instance_method_definitions(class_node).filter do |sibling|
              sibling.method?(:initialize)
            end

          %i[public protected private].each do |visibility|
            @method_definitions[visibility] =
              instance_method_definitions(class_node).filter do |sibling|
                node_visibility(sibling) == visibility
              end
          end
          @method_definitions[:class] =
            class_method_definitions(class_node).to_a

          %i[class public protected private].each do |visibility|
            @method_definitions[visibility].each_cons(2) do |previous, current|
              next if previous.method_name < current.method_name

              message = format(MSG,
                               current:  current.method_name,
                               previous: previous.method_name)
              add_offense(current, message: message)
            end
          end
        end

        private

        def first_line_begin_pos_with_comment(node)
          first_comment = processed_source.ast_with_comments[node].first
          start_line_position(first_comment || node)
        end

        def buffer
          processed_source.buffer
        end

        def end_position_for(node)
          end_line = buffer.line_for_position(node.loc.expression.end_pos)
          buffer.line_range(end_line).end_pos + 1
        end

        def find_visibility_start(node)
          left_siblings_of(node).reverse.find(&method(:visibility_block?))
        end

        def left_siblings_of(node)
          node.parent.children[0, node.sibling_index]
        end

        def method_definition_with_comment(node)
          Parser::Source::Range.new(buffer,
                                    first_line_begin_pos_with_comment(node),
                                    end_position_for(node))
        end

        def node_visibility(node)
          return :class if node.defs_type?
          return :initializer if node.method?(:initialize)

          scope = find_visibility_start(node)
          scope&.method_name || :public
        end

        def start_line_position(node)
          buffer.line_range(node.loc.line).begin_pos - 1
        end
      end
    end
  end
end
