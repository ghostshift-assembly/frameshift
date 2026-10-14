defmodule Frameshift.Illustration.Enclosure do
  @moduledoc """
  Derives conditional wooden enclosure dimensions from explicit component stacks.

  ## Inputs and ownership

  `derive/1` accepts product design inputs in integer micrometres. Every term is
  either a known interval with a source locator, or an explicit missing/conflicting
  value. A region names its complete front-to-rear stack: glass, mat, display or
  electronics, connection/service clearances, retention, backing and mounting.
  Adjacent regions share the outside frame; they are combined with a maximum.
  They are not stacked merely because both components occur in the parts list.

  The consumer defines the regions and required terms. Conjunct owns generic
  physical compatibility and geometric rendering. This module implements the
  product's dimension recipe and produces no fit, safety or received-hardware
  qualification. The wood has no fixed thickness or outside dimensions.

  ## Missing facts

  A missing term leaves the minimum unresolved. Known terms remain visible in a
  partial lower bound, labelled with its scope. Nominal supplier values must be
  submitted as nominal scenario terms; they cannot masquerade as worst-case
  intervals. A complete interval result is conditional on the supplied regions
  covering the full installed envelope and the declared margins.
  """

  @type term_input :: %{
          required(:id) => String.t(),
          required(:state) => :known | :missing | :conflicting,
          optional(:basis) => :bounded | :design | :nominal,
          optional(:min_um) => non_neg_integer(),
          optional(:max_um) => non_neg_integer(),
          optional(:source) => String.t()
        }

  @doc "Calculates width, height and minimum enclosing depth, retaining every unresolved term."
  @spec derive(map()) :: {:ok, map()} | {:error, atom()}
  def derive(%{width: width, height: height, regions: regions})
      when is_list(width) and is_list(height) and is_list(regions) do
    with true <- length(regions) in 1..32,
         {:ok, width} <- stack(width),
         {:ok, height} <- stack(height),
         {:ok, regions} <- region_stacks(regions) do
      unresolved =
        (width.missing ++ height.missing ++ Enum.flat_map(regions, & &1.stack.missing))
        |> Enum.uniq()
        |> Enum.sort()

      lower = regions |> Enum.map(& &1.stack.known_term_lower_bound_um) |> Enum.max()
      nominal = Enum.any?([width, height] ++ Enum.map(regions, & &1.stack), & &1.nominal)

      depth =
        if unresolved == [] and not nominal do
          upper = regions |> Enum.map(& &1.stack.max_um) |> Enum.max()

          %{
            min_um: lower,
            max_um: upper,
            limiting_regions:
              Enum.filter(regions, &(&1.stack.max_um == upper)) |> Enum.map(& &1.id)
          }
        else
          %{min_um: nil, max_um: nil, known_term_lower_bound_um: lower, limiting_regions: []}
        end

      depth =
        if unresolved == [] and nominal do
          Map.merge(depth, %{
            scenario_min_um: regions |> Enum.map(& &1.stack.scenario_min_um) |> Enum.max(),
            scenario_max_um: regions |> Enum.map(& &1.stack.scenario_max_um) |> Enum.max()
          })
        else
          depth
        end

      {:ok,
       %{
         status:
           cond do
             unresolved != [] -> :unknown
             nominal -> :nominal_scenario
             true -> :conditional
           end,
         width: width,
         height: height,
         depth: depth,
         regions: regions,
         unresolved: unresolved,
         scope:
           "Declared component stacks and margins; no hardware or complete-composition qualification"
       }}
    else
      _ -> {:error, :invalid_dimension_input}
    end
  end

  def derive(_), do: {:error, :invalid_dimension_input}

  defp region_stacks(regions) do
    ids = Enum.map(regions, fn region -> if is_map(region), do: Map.get(region, :id) end)

    if Enum.all?(ids, &(is_binary(&1) and byte_size(&1) in 1..128)) and
         Enum.uniq(ids) == ids do
      Enum.reduce_while(regions, {:ok, []}, fn region, {:ok, result} ->
        case stack(Map.get(region, :terms)) do
          {:ok, stack} -> {:cont, {:ok, result ++ [%{id: region.id, stack: stack}]}}
          error -> {:halt, error}
        end
      end)
    else
      {:error, :invalid_regions}
    end
  end

  defp stack(terms) when is_list(terms) and length(terms) in 1..64 do
    ids = Enum.map(terms, fn term -> if is_map(term), do: Map.get(term, :id) end)

    if Enum.uniq(ids) != ids do
      {:error, :duplicate_term}
    else
      result =
        Enum.reduce_while(
          terms,
          {:ok, %{min_um: 0, max_um: 0, missing: [], terms: [], nominal: false}},
          fn
            %{id: id, state: :known, basis: basis, min_um: lower, max_um: upper, source: source} =
                term,
            {:ok, result}
            when is_binary(id) and byte_size(id) in 1..128 and is_integer(lower) and lower >= 0 and
                   is_integer(upper) and upper >= lower and upper <= 10_000_000 and
                   basis in [:bounded, :design, :nominal] and
                   (basis != :nominal or lower == upper) and
                   is_binary(source) and byte_size(source) in 1..1024 ->
              {:cont,
               {:ok,
                %{
                  result
                  | min_um: result.min_um + lower,
                    max_um: result.max_um + upper,
                    nominal: result.nominal or basis == :nominal,
                    terms: result.terms ++ [term]
                }}}

            %{id: id, state: state} = term, {:ok, result}
            when is_binary(id) and byte_size(id) in 1..128 and state in [:missing, :conflicting] ->
              {:cont,
               {:ok, %{result | missing: result.missing ++ [id], terms: result.terms ++ [term]}}}

            _, _ ->
              {:halt, {:error, :invalid_term}}
          end
        )

      case result do
        {:ok, stack} ->
          bounded_lower =
            stack.terms
            |> Enum.filter(&(Map.get(&1, :basis) in [:bounded, :design]))
            |> Enum.map(& &1.min_um)
            |> Enum.sum()

          stack =
            stack
            |> Map.put(:known_term_lower_bound_um, bounded_lower)
            |> Map.put(:scenario_min_um, if(stack.missing == [], do: stack.min_um))
            |> Map.put(:scenario_max_um, if(stack.missing == [], do: stack.max_um))

          {:ok,
           if(stack.missing == [] and not stack.nominal,
             do: stack,
             else: %{stack | min_um: nil, max_um: nil}
           )}

        error ->
          error
      end
    end
  end

  defp stack(_), do: {:error, :invalid_terms}
end
