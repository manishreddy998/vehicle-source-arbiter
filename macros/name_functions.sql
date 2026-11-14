{#
  Name normalization rules, created as SQL functions in the warehouse.
  norm_make(text):  upper-case, punctuation to spaces, collapse spaces. Aliases are applied separately from rules.make_aliases.
  model_tokens(text): upper-case, drop hyphens inside words (F-150 -> F150, CR-V -> CRV), split on spaces, slashes and commas.
  model_core(text): model_tokens minus the tokens listed as noise in rules.model_tokens (drive, cab, body words),
                    re-joined with single spaces. "1500 Classic 4WD" -> "1500 CLASSIC". "Ram 1500 Pickup 2WD" -> "RAM 1500".
#}
{% macro create_name_functions() %}
create schema if not exists rules;
create or replace macro rules.norm_make(s) as
    nullif(trim(regexp_replace(regexp_replace(upper(coalesce(s, '')), '[^A-Z0-9]+', ' ', 'g'), ' +', ' ', 'g')), '');
create or replace macro rules.model_tokens(s) as
    list_filter(string_split_regex(trim(regexp_replace(regexp_replace(upper(coalesce(s, '')), '([A-Z0-9])-([A-Z0-9])', '\1\2', 'g'), '\b([A-Z]{1,3}) CLASS\b', '\1CLASS', 'g')), '[\s/,()]+'), lambda t: t <> '');
create or replace macro rules.model_core(s, noise) as
    nullif(array_to_string(list_filter(rules.model_tokens(s), lambda t: not list_contains(noise, t)), ' '), '');
{% endmacro %}

{# "CLASSIC" -> "Classic", applied to the first variant token for display names #}
{% macro initcap_first(tokens) %}(upper(left({{ tokens }}[1], 1)) || lower(substr({{ tokens }}[1], 2))){% endmacro %}

{# Manufacturer recall codes arrive as "Y55 & Y63", "05C/09C/10C", "SRC XC8/XC9 / SRC RC8/RC9", "12 89 25RC".
   Tokens = the whole string squashed + every part split on separators, squashed, without the SRC prefix.
   Tokens shorter than 3 characters or that look like a year are dropped: "09" matched unrelated Bentley recalls. #}
{% macro recall_code_tokens(col) -%}
list_distinct(list_filter(
    list_concat(
        [regexp_replace(upper(coalesce({{ col }}, '')), '[^A-Z0-9]', '', 'g')],
        list_transform(string_split_regex(regexp_replace(upper(coalesce({{ col }}, '')), '\bSRC\b', '', 'g'), '\s*(/|,|&|;|\bAND\b)\s*'),
                       lambda t: regexp_replace(t, '[^A-Z0-9]', '', 'g'))),
    lambda t: length(t) >= 3 and not regexp_full_match(t, '(19|20)[0-9][0-9]') and t not in ('NONE', 'UNKNOWN', 'TBD')))
{%- endmacro %}
