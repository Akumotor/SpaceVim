
function! SpaceVim#api#job#get() abort
    return map({'start' : '',
                \ 'stop' : '',
                \ 'send' : '',
                \ 'status' : '',
                \ 'list' : '',
                \ 'info' : ''
                \ },
                \ "function('s:' . v:key)"
                \ )
endfunction

" make vim and neovim use same job func.
let s:jobs = {}
let s:nvim_job = has('nvim')
let s:vim_job = !has('nvim') && has('job') && has('patch-7.4.1590')
function! s:warn(...) abort
    if len(a:000) == 0
        echohl WarningMsg | echom 'Current version do not support job feature!' | echohl None
    elseif len(a:000) == 1 && type(a:1) == type('')
        echohl WarningMsg | echom a:1| echohl None
    else
    endif
endfunction
function! s:warp(argv, opts) abort
    let obj = {}
    let obj._argv = a:argv
    let obj._opts = a:opts
    " @vimlint(EVL103, 1, a:job_id)
    function! obj._out_cb(job_id, data) abort
        if has_key(self._opts, 'on_stdout')
            call self._opts.on_stdout(self._opts.jobpid, [a:data], 'stdout')
        endif
    endfunction

    function! obj._err_cb(job_id, data) abort
        if has_key(self._opts, 'on_stderr')
            call self._opts.on_stderr(self._opts.jobpid, [a:data], 'stderr')
        endif
    endfunction

    function! obj._exit_cb(job_id, data) abort
        if has_key(self._opts, 'on_exit')
            call self._opts.on_exit(self._opts.jobpid, a:data, 'exit')
        endif
    endfunction
    " @vimlint(EVL103, 0, a:job_id)

    let obj = {
                \ 'argv': a:argv,
                \ 'opts': {
                \ 'mode': 'nl',
                \ 'out_cb': obj._out_cb,
                \ 'err_cb': obj._err_cb,
                \ 'exit_cb': obj._exit_cb,
                \ }
                \ }
    if has_key(a:opts, 'cwd')
        call extend(obj.opts, {'cwd' : a:opts.cwd})
    endif
    return obj
endfunction

" start a job, and return the job_id.
function! s:start(argv, ...) abort
    if s:nvim_job
        if len(a:000) > 0
            let job = jobstart(a:argv, a:1)
        else
            let job = jobstart(a:argv)
        endi
        let msg = ['process '. jobpid(job), ' run']
        call extend(s:jobs, {job : msg})
        return job
    elseif s:vim_job
        if len(a:000) > 0
            let opts = a:1
        else
            let opts = {}
        endif
        let id = len(s:jobs) + 1
        let opts.jobpid = id
        let wrapped = s:warp(a:argv, opts)
        if has_key(wrapped.opts, 'cwd')
            let old_wd = getcwd()
            let cwd = expand(wrapped.opts.cwd, 1)
            " Avoid error E475: Invalid argument: cwd
            call remove(wrapped.opts, 'cwd')
            exe 'cd' fnameescape(cwd)
        endif
        let job = job_start(wrapped.argv, wrapped.opts)
        if exists('old_wd')
            exe 'cd' fnameescape(old_wd)
        endif
        call extend(s:jobs, {id : job})
        return id
    else
        call s:warn()
    endif
endfunction

function! s:stop(id) abort
    if s:nvim_job
        if has_key(s:jobs, a:id)
            call jobstop(a:id)
            call remove(s:jobs, a:id)
        else
            call s:warn('No job with such id')
        endif
    elseif s:vim_job
        if has_key(s:jobs, a:id)
            call job_stop(get(s:jobs, a:id))
            call remove(s:jobs, a:id)
        endif
    else
        call s:warn()
    endif
endfunction

function! s:send(id, data) abort
    if s:nvim_job
        if has_key(s:jobs, a:id)
            if type(a:data) == type('')
                call jobsend(a:id, [a:data, ''])
            else
                call jobsend(a:id, a:data)
            endif
        else
            call s:warn('No job with such id')
        endif
    elseif s:vim_job
        if has_key(s:jobs, a:id)
            let job = get(s:jobs, a:id)
            let chanel = job_getchannel(job)
            call ch_sendraw(chanel, a:data . "\n")
        else
            call s:warn('No job with such id')
        endif
    else
        call s:warn()
    endif
endfunction

function! s:status(id) abort
    if s:nvim_job
        if has_key(s:jobs, a:id)
            return get(s:jobs, a:id)[1]
        endif
    elseif s:vim_job
        if has_key(s:jobs, a:id)
            return job_status(get(s:jobs, a:id))
        endif
    else
        call s:warn('No job with such id!')
    endif
endfunction

function! s:list() abort
    return copy(s:jobs)
endfunction

function! s:info(id) abort
    let info = {}
    if s:nvim_job
        let info.status = s:status(a:id)
        let info.job_id = a:id
        return info
    elseif s:vim_job
        if has_key(s:jobs, a:id)
            return job_info(get(s:jobs, a:id))
        else
            call s:warn('No job with such id!')
        endif
    else
        call s:warn()
    endif
endfunction
