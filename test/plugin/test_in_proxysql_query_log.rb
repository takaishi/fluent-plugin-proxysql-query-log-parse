require "helper"
require "fluent/plugin/in_proxysql_query_log.rb"

class ProxysqlQueryLogInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  TMP_DIR = File.dirname(__FILE__) + '/../tmp/proxysql_query_log'
  CONFIG = config_element('ROOT', '', {
      'path' => "#{TMP_DIR}/query_log"
  })

  test 'singlefile' do
    File.open("#{TMP_DIR}/query_log", 'wb') {|f|
      write_record(f)
    }
    config = CONFIG
    d = create_driver(config)
    d.run(expect_emits: 1) do
      File.open("#{TMP_DIR}/query_log", "ab") {|f|
        write_record(f)
      }
    end

    events = d.events
    assert_equal(true, events.length > 0)
    assert_equal(1, 1)
    assert_equal(9, events[0][2]['thread_id'])
    assert_equal('root', events[0][2]['username'])
    assert_equal('alpaca', events[0][2]['schema_name'])
    assert_equal('127.0.0.1:34612', events[0][2]['client'])
    assert_equal(0, events[0][2]['HID'])
    assert_equal('127.0.0.1:3306', events[0][2]['server'])
    assert_equal('2018-05-10 09:24:16', events[0][2]['start_time'])
    assert_equal('2018-05-10 09:24:16', events[0][2]['end_time'])
    assert_equal('0xD69C6B36F32D2EAE', events[0][2]['digest'])
    assert_equal('SELECT * FROM test', events[0][2]['query'])
  end

  private

  def write_record(f)
    q = ProxysqlQueryLog::Query.new
    q.thread_id = 9
    q.username = 'root'
    q.schema_name = 'alpaca'
    q.client = '127.0.0.1:34612'
    q.hid = 0
    q.server = '127.0.0.1:3306'
    q.start_time = 1525944256367381
    q.end_time = 1525944256367837
    q.digest = '0xD69C6B36F32D2EAE'
    q.query = 'SELECT * FROM test'
    size = 0
    buf = ''
    io = StringIO.new(buf)

    io.write([0].pack('C*'))
    size += 1
    io.write([q.thread_id].pack('C*'))
    size += 1

    io.write([q.username.size].pack('C*'))
    size += 1
    io.write(q.username)
    size += q.username.size

    io.write([q.schema_name.size].pack('C*'))
    size += 1
    io.write(q.schema_name)
    size += q.schema_name.size

    io.write([q.client.size].pack('C*'))
    size += 1
    io.write(q.client)
    size += q.client.size

    io.write([q.hid].pack('C*'))
    size += 1

    io.write([q.server.size].pack('C*'))
    size += 1
    io.write(q.server)
    size += q.server.size

    io.write([0xfe].pack('C*'))
    size += 1
    io.write([q.start_time].pack('Q*'))
    size += 8

    io.write([0xfe].pack('C*'))
    size += 1
    io.write([q.end_time].pack('Q*'))
    size += 8

    io.write([0xfe].pack('C*'))
    size += 1
    io.write(q.digest.gsub(/0x/, '').scan(/.{1,8}/).map{|s| s.hex}.pack('I*'))
    size += 8

    io.write([q.query.size].pack('C*'))
    size += 1
    io.write(q.query)
    size += q.query.size

    f.write([size, 0, 0, 0, 0, 0, 0, 0].pack('C*'))
    f.write(buf)
  end

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::ProxysqlQueryLogInput).configure(conf)
  end
end
