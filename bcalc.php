<!DOCTYPE html>
<html lang="en">
<head>
  <title>bonus</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="http://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.0/jquery.min.js"></script>
  <script src="http://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"></script>
</head>
<body>

<div class="container">
  <form role="form" onsubmit="return calculate();">
  <table class="table">
    <thead>
      <tr>
        <th>Total Expenses</th>
        <th>Total Revenue</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <div class="form-group">
            <input type="text" placeholder="Please enter Expenses" class="form-control" required id="txtExpenses" />
          </div>
        </td>
        <td>
            <input type="text" placeholder="Please enter Revenue" class="form-control" required id="txtRevenue" />
        </td>
        <td>
            <input type="submit" class="btn btn-success" value="Calculate" />
        </td>
      </tr>
    </tbody>
  </table>

  <br><br>
  <h3>Result</h3>

  <table class="table">
    <thead>
      <tr>
        <th>Expense</th>
        <th>Revenue</th>
        <th>Level 1</th>
        <th>Level 2</th>
        <th>Level 3</th>
        <th>Total</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td id="tdExpense"></td>
        <td id="tdRevenue"></td>
        <td id="tdValue1"></td>
        <td id="tdValue2"></td>
        <td id="tdValue3"></td>
        <td id="tdTotal"></td>
      </tr>
    </tbody>
  </table>
</form>
 <h3>Example</h3>

  <table class="table">
    <thead>
      <tr>
        <th>Expense</th>
        <th>Revenue</th>
        <th>Level 1</th>
        <th>Level 2</th>
        <th>Level 3</th>
        <th>Total</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>100,000</td>
        <td>400,000</td>
        <td>10000</td>
        <td>60000</td>
        <td>35000</td>
        <td>105000</td>
      </tr>
    </tbody>
  </table>


</div>

</body>
</html>
<script type="text/javascript">

  

  function calculate()
  {
    var Expenses         = ($('#txtExpenses').val());
    var resExpense       = Expenses.split(",");
    var Expense = '';

        for(var e = 0; e < resExpense.length; e++)
		    {
			          Expense = Expense+resExpense[e];
				      }

    var Revenues          = ($('#txtRevenue').val());
    var resRevenue        = Revenues.split(",");
    var Revenue = '';


    for(var r = 0; r < resRevenue.length; r++)
    {
         Revenue = Revenue+resRevenue[r];
    }

    var ExpenseTwice    = Expense * 2;
    var ExpenseThrice   = Expense * 3;
    var Value1          = 0;
    var Value2          = 0;
    var Value3          = 0;


    if(Revenue == ExpenseTwice)
    {
      Value1  = (Revenue * 5) / 100;
    }
    if(Revenue > ExpenseTwice)
    {
      Value1      = (ExpenseTwice * 5) / 100;
      var Diff    = Revenue - ExpenseTwice;
      var Value2  = (Diff * 20) / 100;
    }
    if(Revenue > ExpenseThrice)
    {
      Value1      = (ExpenseTwice * 5) / 100;
      Value2      = (ExpenseThrice * 20) / 100;
      var Diff    = Revenue - ExpenseThrice;
      var Value3  = (Diff * 35) / 100;
    }
		        
      var Total = Value1 + Value2 + Value3;

      $('#tdExpense').html(Expense);
      $('#tdRevenue').html(Revenue);
      $('#tdValue1').html(Value1);
      $('#tdValue2').html(Value2);
      $('#tdValue3').html(Value3);
      $('#tdTotal').html(Total);
      return false;
    }
  </script>
