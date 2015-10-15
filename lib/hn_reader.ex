defmodule HnReader do
  import Enum
  @hn_url "https://news.ycombinator.com"

  def title_texts(titles), do: map(titles, fn({title, _, _}) -> title end)

  def get_hn3() do get_hn3(3) end
  def get_hn3(number) do
    parent = self()

    HTTPotion.get(@hn_url).body
    |> Exquery.tree
    |> Exquery.Query.css(".title > a")
    |> take(number)
    |> map(&(parse_link(&1)))
    |> each(&(spawn fn -> load_link(parent, &1) end))

    handle_message(number, [])
  end

  defp handle_message(0, pages) do pages end
  defp handle_message(number, pages) do
    receive do
      {:ok, page} -> handle_message(number - 1, [page | pages])
      _           -> handle_message(number - 1, pages)
      after 5_000 -> pages
    end
  end

  defp load_link(parent, link) do
    {title, url} = link
    send parent, make_response(title, url, HTTPotion.get(url))
  end

  defp make_response(title, url, %{:status_code => status_code, :body => body} = response) do
    data = {title, url, String.length(body)}
    case status_code do
      200   -> {:ok, data}
      400   -> {:err, data}
      other -> {other, data}
    end
  end

  defp parse_link(link) do
    {{:tag, _, url_array}, [{:text, text, _}]} = link
    [{"href", url}] = filter(url_array, fn({tag, _}) -> tag == "href" end)
    {text, url}
  end
end
