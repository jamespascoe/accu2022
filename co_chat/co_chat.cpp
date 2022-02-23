//
// co_chat.cpp
// ~~~~~~~~~~~
//
// g++-11 -I/usr/local/boost_1_78_0/include -fcoroutines -std=c++20 -Wall -Werror co_receive.cpp -l pthread
// ./a.out 127.0.0.1 6666 127.0.0.1 6667
//

#include <boost/asio.hpp>
#include <boost/regex.hpp>
#include <boost/asio/experimental/as_tuple.hpp>
#include <boost/asio/experimental/awaitable_operators.hpp>
#include <boost/asio/experimental/channel.hpp>
#include <iostream>

using boost::asio::awaitable;
using boost::asio::buffer;
using boost::asio::dynamic_buffer;
using boost::asio::co_spawn;
using boost::system::error_code;
using boost::asio::detached;
using boost::asio::experimental::as_tuple;
using boost::asio::experimental::channel;
using boost::asio::io_context;
using boost::asio::ip::tcp;
using boost::asio::steady_timer;
using boost::asio::use_awaitable;
namespace this_coro = boost::asio::this_coro;
using namespace boost::asio::experimental::awaitable_operators;
using namespace std::literals::chrono_literals;

awaitable<void> transmit(tcp::socket remote_sock, tcp::endpoint remote)
{
  for (;;) {
    auto [e] = co_await remote_sock.async_connect(remote, as_tuple(use_awaitable));
    if (!e)
    {
      std::cout << "Connected to: " << remote << std::endl;
      break;
    }
  }

  std::string data;
  for (;;)
  {
    struct pollfd input[1] = {{.fd = 0, .events = POLLIN}};
    if (poll(input, 1, 100)) {
      char c;
      while (std::cin.get(c) && c != '\n')
        data += c;

      data += "\r\n";
    }

    co_await async_write(remote_sock, buffer(data), as_tuple(use_awaitable));

    data.clear();
  }
}

awaitable<void> receive(io_context& ctx, tcp::endpoint listen)
{
  tcp::acceptor acceptor(ctx, listen);
  for (;;)
  {
    auto [e, client] = co_await acceptor.async_accept(as_tuple(use_awaitable));
    if (!e)
    {
      std::string str;

      // TODO - do this until the client disconnects
      for (;;) {
        co_await async_read_until(client, dynamic_buffer(str), boost::regex("\r\n"), use_awaitable);

        std::cout << client.remote_endpoint() << "> " << str << std::endl;
        str.clear();
      }
    }
    else
    {
      std::cerr << "Accept failed: " << e.message() << "\n";
      steady_timer timer(co_await this_coro::executor);
      timer.expires_after(100ms);
      co_await timer.async_wait(use_awaitable);
    }
  }
}

int main(int argc, char* argv[])
{
  try
  {
    if (argc != 5)
    {
      std::cerr << "Usage: co_receive";
      std::cerr << " <listen_address> <listen_port>";
      std::cerr << " <remote_address> <remote_port>\n";
      return 1;
    }

    io_context ctx;

    auto listen_endpoint =
      *tcp::resolver(ctx).resolve(argv[1], argv[2], tcp::resolver::passive);

    auto remote_endpoint =
      *tcp::resolver(ctx).resolve(argv[3], argv[4]);

    tcp::socket remote_sock(ctx);
    co_spawn(ctx, transmit(std::move(remote_sock), remote_endpoint), detached);
    co_spawn(ctx, receive(ctx, listen_endpoint), detached);
    ctx.run();
  }
  catch (std::exception& e)
  {
    std::cerr << "Exception: " << e.what() << "\n";
  }
}
