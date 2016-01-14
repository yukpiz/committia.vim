let g:committia#git#cmd = get(g:, 'committia#git#cmd', 'git')
let g:committia#git#diff_cmd = get(g:, 'committia#git#diff_cmd', 'diff -u --cached --no-color')
let g:committia#git#status_cmd = get(g:, 'committia#git#status_cmd', 'status -b')
let g:committia#git#log_cmd = get(g:, 'committia#git#log_cmd', 'log --oneline')
let g:committia#git#log_cnt = get(g:, 'committia#git#log_cnt', 20)

if ! executable(g:committia#git#cmd)
    echoerr g:committia#git#cmd . " command is not found"
endif

function! s:search_git_dir() abort
    " '/.git' is unnecessary under submodule directory.
    if expand('%:p') =~# '[\\/]\.git[\\/]\%(modules[\\/].\+[\\/]\)\?COMMIT_EDITMSG$'
        return expand('%:p:h')
    endif

    let root = matchstr(system(g:committia#git#cmd . ' rev-parse --show-cdup'),  '[^\n]\+')
    if v:shell_error
        throw "committia: git: Failed to execute 'git rev-parse'"
    endif

    if !isdirectory(root . $GIT_DIR)
        throw "committia: git: Failed to get git-dir from $GIT_DIR"
    endif

    return root . $GIT_DIR
endfunction

function! s:execute_git(cmd, git_dir) abort
    let diff_temp = join([
    \   '*** Example *****',
    \   '* Fix typo in docs',
    \   '* Remove unused code',
    \   '* Remove use of deprecated method',
    \   '* Update Modernizr to v1.6',
    \   '* Make it possible to have IDs per request',
    \   '* Make sure to reset default_url_options',
    \   '* Don''t use "assert_not_nil"',
    \   '* Allow the user to drag faster',
    \   '* Remove methods to avoid warnings'
    \],"\n")
    let logs = split(system(printf(
    \   '%s %s -n %d',
    \   g:committia#git#cmd,
    \   g:committia#git#log_cmd,
    \   g:committia#git#log_cnt)), "\n")
    let log_temps = ["*** Commit Histories *****"] + logs
    return diff_temp . "\n\n" . join(log_temps, "\n* ") . "\n\n" . system(printf('%s --git-dir="%s" --work-tree="%s" %s', g:committia#git#cmd, a:git_dir, fnamemodify(a:git_dir, ':h'), a:cmd))
endfunction

function! committia#git#diff(...) abort
    let git_dir = a:0 > 0 ? a:1 : s:search_git_dir()

    if git_dir ==# ''
        throw "committia: git: Failed to get git-dir"
    endif

    if $GIT_INDEX_FILE == ''
        let lock_file = git_dir . (has('win32') || has('win64') ? '\' : '/') . 'index.lock'
        if filereadable(lock_file)
            let $GIT_INDEX_FILE = lock_file
        else
            let $GIT_INDEX_FILE = git_dir . (has('win32') || has('win64') ? '\' : '/') . 'index'
        endif
        let index_file_was_not_found = 1
    endif

    let diff =  s:execute_git(g:committia#git#diff_cmd, git_dir)
    if v:shell_error
        throw "committia: git: Failed to execute diff command"
    endif

    if exists('l:index_file_was_not_found')
        let $GIT_INDEX_FILE = ''
    endif
    return split(diff, '\n')
endfunction

function! committia#git#status(...) abort
    let git_dir = a:0 > 0 ? a:1 : s:search_git_dir()
    if git_dir ==# ''
        return ''
    endif

    let status = s:execute_git(g:committia#git#status_cmd, git_dir)
    if v:shell_error
        throw "committia: git: Failed to execute status command"
    endif
    return map(split(status, '\n'), 'substitute(v:val, "^", "# ", "g")')
endfunction

function! committia#git#search_end_of_edit_region() abort
    call search('\m\%(\_^\s*\_$\n\)*\_^\s*# Please enter the commit', 'cW')
endfunction
