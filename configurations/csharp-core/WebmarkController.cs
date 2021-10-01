using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using Npgsql;
using Dapper;

namespace aspnetapp.Controllers
{
    public class Fortune
    {
        public string id { get; set; }
        public string message { get; set; }
    }

    public class WebmarkController : Controller
    {
        private string connectionString;

        public WebmarkController(IConfiguration configuration)
        {
            connectionString = $"User ID=postgres;Password=webmark;Host=webmarkdb;Port=5432;Database=postgres;Pooling=true;Trust Server Certificate=true;";
        }

        private IDbConnection GetConnection()
        {
            return new NpgsqlConnection(connectionString);
        }

        [Route("/helloworld")]
        public IActionResult HelloWorld()
        {
            return Content("Hello, world!");
        }

        [Route("/10-fortunes")]
        public IActionResult First10Fortunes()
        {
            using (IDbConnection dbConnection = GetConnection())
            {
                dbConnection.Open();
                var list = dbConnection.Query<Fortune>("SELECT id, message FROM fortunes LIMIT 10");
                return Json(list);
            }
        }

        [Route("/all-fortunes")]
        public IActionResult AllFortunes()
        {
            using (IDbConnection dbConnection = GetConnection())
            {
                dbConnection.Open();
                var list = dbConnection.Query<Fortune>("SELECT id, message FROM fortunes");
                return Json(list);
            }
        }

        [Route("/primes")]
        public IActionResult Primes()
        {
            var list = new List<int>();
            for (var test = 2; test <= 10000; ++test) {
                var ok = true;
                for (var v = 2; v < test; ++v) {
                    if (test % v != 0) continue;
                    ok = false;
                    break;
                }
                if (ok) {
                    list.Add(test);
                }
            }
            return Content(string.Join('\n', list));
        }
    }
}