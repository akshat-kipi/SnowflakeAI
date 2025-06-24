--------------------------------------------------------------------------------------------------
-- AI_COMPLETE
--------------------------------------------------------------------------------------------------

create or replace table insights AS
with IMAGE_INSIGHTS AS
(
    select
        created_at,
        user_id,
        relative_path as ticket_id,
        img_file as input_file,
        file_url as input_file_url,
        AI_COMPLETE(
            'pixtral-large',
            prompt(
                'Summarize this issue shown in this screenshot in one concise sentence: {0}',
                img_file
            )
        ) as summary,
        summary as content
    from
        images
),
EMAIL_INSIGHTS as 
(
    select
        created_at,
        user_id,
        ticket_id::text as ticket_id,
        null as input_file,
        '' as input_file_url,
        content as content,
        AI_COMPLETE(
            'claude-3-7-sonnet',
            prompt(
                'Summarize this issue in one concise sentence. 
If the user mentioned anything related to music preference, please keep that information: {0}',
                content
            )
        ) as summary
    from
        emails
)
select
    'Image' as source,
    created_at,
    user_id,
    ticket_id,
    input_file,
    input_file_url,
    content,
    summary
from
    IMAGE_INSIGHTS
union
select
    'Email' as source,
    created_at,
    user_id,
    ticket_id,
    input_file,
    input_file_url,
    content,
    summary
from
    EMAIL_INSIGHTS;


select 
    user_id, source, input_file, summary, content, input_file_url 
from insights
order by input_file_url desc;


--------------------------------------------------------------------------------------------------
-- AI_FILTER
--------------------------------------------------------------------------------------------------

select 
    c.content as "CUSTOMER ISSUE",
    s.solution,
    c.created_at,
    AI_FILTER(prompt('You are provided a customer issue and a solution center article. Please check if the solution article can address customer concerns. Reminder to check if the error details are matching and provide a boolean response. Customer issues: {0}; \n\nSolution: {1}', c.content, s.solution)) AS FILTER_CONDITION
from
    INSIGHTS c
left join
    SOLUTION_CENTER_ARTICLES s
on AI_FILTER(prompt('You are provided a customer issue and a solution center article. Please check if the solution article can address customer concerns. Reminder to check if the error details are matching. Customer issues: {0}; \n\nSolution: {1}', c.content, s.solution))
order by created_at asc;

select 
    user_id, source, input_file, summary, content, input_file_url 
from insights i
where AI_FILTER(prompt('Please check if the discussion is about an expired session: {0}', i.summary));

select 
    user_id, source, input_file, summary, content, input_file_url 
from insights i
where AI_FILTER(prompt('Please check if the discussion is about an expired session: {0}, and the length of following value is more than 2: "{1}"', i.summary, i.user_id)); -- Strings not numbers

select 
    -- AI_FILTER(prompt('Please check if the following summary contains the work "session": {0}', x.summary)) AS filterval
    count(*) as total_tickets,
    count(distinct user_id) as unique_users
from (select * from insights order by random() limit 200) x
group by AI_FILTER(prompt('Please check if the following summary contains the work "session": {0}', x.summary))
order by total_tickets desc;


--------------------------------------------------------------------------------------------------
-- AI_AGG
--------------------------------------------------------------------------------------------------

select 
    monthname(created_at) as month, 
    count(*) as total_tickets,
    count(distinct user_id) as unique_users,
    AI_AGG(summary,'Analyze all the support ticket reviews and provide a comprehensive list of all issues mentioned. Format your response as a bulleted list of         issues with their approximate frequency in percentage.') as top_issues_reported,
from (select * from insights order by random() limit 200)
group by month
order by total_tickets desc,month desc;


select * from insights;



--------------------------------------------------------------------------------------------------
-- AI_CLASSIFY
--------------------------------------------------------------------------------------------------

with filtered as 
(
    select * from 
    (
        select * 
        from insights 
        order by random() limit 500
    )
    where AI_FILTER(prompt('I am trying to find if the customer has mentioned any music genre perference in their comment. 
    Is this comment mentioning specific music genre preference from the customer?: {0};', summary))
)
select 
    source, 
    summary,
    AI_CLASSIFY('Please help me classify the music preference mentioned in this comment: ' || summary,SPLIT('Electronic/Dance Music (EDM), Jazz, Indie/Folk, Rock, Classical, World Music, Blues, Pop', ','))['labels'][0] as classified_label
from filtered;







