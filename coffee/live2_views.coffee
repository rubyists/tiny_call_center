#
# Views for Live2
#

Serenade.view('queueList', """
ul#queues.dropdown-menu
  - collection @queues
      li
        a[href="#" event:click=showQueue!] @name
""")

Serenade.view('agent', """
.span2.agent[event:dblclick=details!]
  .row-fluid
    .span2.extension @extension
    .span10.username @username
  - collection @calls
    .row-fluid.call
      .span3.duration @duration
      .span9.name-and-number @display_cid
  .row-fluid
    .span3.atime @timeSinceStatusChange
    .span9.state @state
  .status @status
  .queue @queue
  .lastStatusChange @lastStatusChange
  div[class=@queue]
""")

Serenade.view('agentCall', """
tr
  td @display_cid
  td @createdTime
  td @queue
  td
    a[event:click=calltap!]
      i.icon-headphones
""")

Serenade.view('agentDetail', """
.modal
  .modal-header
    a.close[data-dismiss="modal"] "x"
    h3 @username " - " @id
  .modal-body
    ul.nav.nav-tabs
      li
        a[data-toggle="tab" href="#agentDetailCalls"] "Calls"
      li
        a[data-toggle="tab" href="#agentDetailOverview"] "Overview"
      li
        a[data-toggle="tab" href="#agentDetailStatusLog"] "Status Log"
      li
        a[data-toggle="tab" href="#agentDetailStateLog"] "State Log"
      li
        a[data-toggle="tab" href="#agentDetailCallLog"] "Call History"
    .tab-content
      #agentDetailCalls.tab-pane
        table
          thead
            tr
              th "CID"
              th "Time"
              th "Queue"
              th "Tap"
          tbody
            - collection @calls
              - view "agentCall"
      #agentDetailOverview.tab-pane
        h2 "Status"
        .btn-group[data-toggle="buttons-radio"]
          button.btn.status-available[event:click=statusAvailable] "Available"
          button.btn.status-available-on-demand[event:click=statusAvailableOnDemand] "Available (On Demand)"
          button.btn.status-on-break[event:click=statusOnBreak] "On Break"
          button.btn.status-logged-out[event:click=statusLoggedOut] "Logged Out"

        h2 "State"
        .btn-group[data-toggle="buttons-radio"]
          button.btn.state-waiting[event:click=stateWaiting] "Ready"
          button.btn.state-idle[event:click=stateIdle] "Wrap Up"
      #agentDetailStatusLog.tab-pane
        "Loading Status Log..."
      #agentDetailStateLog.tab-pane
        "Loading State Log..."
      #agentDetailCallLog.tab-pane
        "Loading Call History..."
""")

Serenade.view('agentStatusLog', """
table
  thead
    tr
      th "Status"
      th "Time"
  tbody
    - collection @statuses
      tr
        td @created_at
        td @new_status
""")

Serenade.view('agentStateLog', """
table
  thead
    tr
      th "State"
      th "Time"
  tbody
    - collection @states
      tr
        td @created_at
        td @new_state
""")

Serenade.view('agentCallLog', """
table
  thead
    tr
      th "username"
      th "caller_id_number"
      th "caller_id_name"
      th "destination_number"
      th "channel"
      th "context"
      th "start_stamp"
      th "end_stamp"
      th "couch_id"
      th "duration"
      th "billsec"
      th "start_time"
  tbody
    - collection @calls
      tr
        td @username
        td @caller_id_number
        td @caller_id_name
        td @destination_number
        td @channel
        td @context
        td @start_stamp
        td @end_stamp
        td @couch_id
        td @duration
        td @billsec
        td @start_time
""")
