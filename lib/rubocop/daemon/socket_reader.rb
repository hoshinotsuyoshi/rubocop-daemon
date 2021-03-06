# frozen_string_literal: true

module RuboCop
  module Daemon
    class SocketReader
      Request = Struct.new(:header, :body)
      Header = Struct.new(:token, :cwd, :command, :args)

      def initialize(socket, verbose)
        @socket = socket
        @verbose = verbose
      end

      def read!
        request = parse_request(@socket.read)

        Helper.redirect(
          stdin: StringIO.new(request.body),
          stdout: @socket,
          stderr: @socket,
        ) do
          create_command_instance(request).run
        end
      end

      private

      def parse_request(content)
        raw_header, *body = content.lines
        if @verbose
          puts raw_header.to_s
          puts "STDIN: #{body.size} lines" if body.any?
        end

        Request.new(parse_header(raw_header), body.join)
      end

      def parse_header(header)
        token, cwd, command, *args = header.shellsplit
        Header.new(token, cwd, command, args)
      end

      def create_command_instance(request)
        klass = find_command_class(request.header.command)

        klass.new(
          request.header.args,
          token: request.header.token,
          cwd: request.header.cwd,
        )
      end

      def find_command_class(command)
        case command
        when 'stop' then ServerCommand::Stop
        when 'exec' then ServerCommand::Exec
        else
          raise UnknownServerCommandError, "#{command.inspect} is not a valid command"
        end
      end
    end
  end
end
