# encoding: utf-8

require 'erb'

module Nanoc::Filters
  class ERB < Nanoc::Filter

    identifier :erb

    # Runs the content through [ERB](http://ruby-doc.org/stdlib/libdoc/erb/rdoc/classes/ERB.html).
    #
    # @param [String] content The content to filter
    #
    # @option params [Integer] safe_level (nil) The safe level (`$SAFE`) to
    #   use while running this filter
    #
    # @option params [String] trim_mode (nil) The trim mode to use
    #
    # @return [String] The filtered content
    def run(content, params = {})
      # Add locals
      assigns.merge!(params[:locals] || {})

      # Create context
      context = ::Nanoc::Context.new(assigns.merge(assigns: assigns))

      # Get binding
      proc = assigns[:content] ? -> { assigns[:content] } : nil
      assigns_binding = context._binding(&proc)

      # Get result
      safe_level = params[:safe_level]
      trim_mode = params[:trim_mode]
      erb = ::ERB.new(content, safe_level, trim_mode)
      erb.filename = filename
      erb.result(assigns_binding)
    end

  end
end
