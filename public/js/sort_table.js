var directions = {};
function sorter(trigger, sortOn, sortType){
  trigger.click(function(event){
    var table = $(event.target).closest('.table')
    var direction = directions[sortOn] === 'asc' ? 'desc' : 'asc';
    directions[sortOn] = direction;
    table.sort({
      sortOn: sortOn,
      direction: direction,
      sortType: sortType,
    });
    table.prepend($('.head', table));
    $('.head > *', table).removeClass('asc');
    $('.head > *', table).removeClass('desc');
    trigger.addClass(direction);
  });
}
