-- should fail with undefined
show plv8.context;
-- should fail with undefined
do $$ plv8.elog(NOTICE, val) $$ language plv8;
show plv8.context;

do $$ val = 'data' $$ language plv8;
do $$ plv8.elog(NOTICE, val) $$ language plv8;

set plv8.context = 'test1';
-- should fail with undefined
do $$ plv8.elog(NOTICE, val) $$ language plv8;

do $$ val = 'data1' $$ language plv8;
do $$ plv8.elog(NOTICE, val) $$ language plv8;

set plv8.context = 'test2';
-- should fail with undefined
do $$ plv8.elog(NOTICE, val) $$ language plv8;

do $$ val = 'data2' $$ language plv8;
do $$ plv8.elog(NOTICE, val) $$ language plv8;

set plv8.context = 'test1';
do $$ plv8.elog(NOTICE, val) $$ language plv8;

reset plv8.context;
do $$ plv8.elog(NOTICE, val) $$ language plv8;

set plv8.context = 'test2';
do $$ plv8.elog(NOTICE, val) $$ language plv8;

reset plv8.context;

-- should fail, cannot change context when running in context
do $$ plv8.execute(`set plv8.context = 'fail'`) $$ language plv8;

create function ctx_start() returns void as $$
    context = plv8.execute(`show plv8.context`)[0]['plv8.context'];
    plv8.elog(NOTICE, `Start proc finished for context: '${context}'`);
$$ language plv8;

\c

set plv8.start_proc = 'ctx_start';
set plv8.context = 'start1';
do $$ plv8.elog(NOTICE, context) $$ language plv8;

reset plv8.context;
do $$ plv8.elog(NOTICE, context) $$ language plv8;
reset plv8.start_proc;

-- START user contexts LRU functionality checks
create or replace function noop() returns void as $$ $$ language plv8;

do
$$
    declare
        size integer;
        ctx varchar;
    begin
        execute 'select noop()';
        execute 'show plv8.context_cache_size' into size;
        size := size * 2;
        for i in 1..size
            loop
                ctx = 'check' || i;
                execute 'set plv8.context = ' || quote_literal(ctx);
                execute 'select noop()';
            end loop;
    end;
$$ language plpgsql;

do $$
    const contexts_alive = plv8.memory_usage().number_of_native_contexts;
    const data = plv8.execute(`show plv8.context_cache_size`);
    const size = Number.parseInt(data[0]['plv8.context_cache_size']);
    // there are 2 additional contexts that are never killed: `default` and `dialect compile`
    plv8.elog(NOTICE, (size + 2 == contexts_alive) ? 'OK' : 'FAIL');
$$ language plv8;

drop function noop();
-- END LRU check
